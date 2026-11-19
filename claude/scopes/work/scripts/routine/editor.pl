# Typed JSON boundary for routine.sh. Only the shell owns files and launchd.
use strict;
use warnings;
use JSON::PP;
use Time::HiRes qw(time);
use Digest::SHA qw(sha256_hex);

my $json = JSON::PP->new->utf8->canonical->allow_nonref;
sub reject {
    my ($code, $message) = @_;
    print $json->encode({status => 'error', code => $code, message => $message}), "\n";
    exit 1;
}
sub invalid { reject('invalid', $_[0]) }
sub conflict { reject('conflict', $_[0]) }
sub object {
    my ($bytes) = @_;
    my $obj = eval { $json->decode($bytes) };
    return ref($obj) eq 'HASH' ? $obj : undef;
}
sub raw_manifest {
    my ($file) = @_;
    open my $fh, '<:raw', $file or conflict('Reopen the routine. Its manifest is unavailable.');
    my $size = read $fh, my $bytes, 8193;
    defined($size) && $size <= 8192 or conflict('Repair the unreadable or oversized manifest.');
    return $bytes;
}
sub description {
    my ($s) = @_;
    defined($s) && $json->encode($s) =~ /^"/ && length($s) <= 200 && $s !~ /[\p{Cc}\p{Zl}\p{Zp}]/
        or invalid('Use a single line of plain text up to 200 characters.');
    return $s;
}
sub slots {
    my ($slots) = @_;
    ref($slots) eq 'ARRAY' && @$slots or invalid('Supply at least one calendar slot.');
    my (@slots, %seen);
    for my $s (@$slots) {
        ref($s) eq 'HASH' && !grep(!/\A(hour|minute|weekday)\z/, keys %$s)
            or invalid('Each slot accepts only hour, minute and optional weekday.');
        my %slot = (weekday => undef);
        for my $pair ([hour => 23], [minute => 59], [weekday => 7]) {
            my ($k, $max) = @$pair;
            next if $k eq 'weekday' && !defined($s->{$k});
            defined($s->{$k}) && $json->encode($s->{$k}) =~ /\A[0-9]+\z/ && $s->{$k} <= $max
                or invalid("Use an integer $k between 0 and $max.");
            $slot{$k} = $s->{$k};
        }
        $slot{hour} != 1 && $slot{hour} != 2 or invalid('Choose a time outside 01:00 through 02:59.');
        $slot{weekday} = 0 if defined($slot{weekday}) && $slot{weekday} == 7;
        push @slots, \%slot unless $seen{$json->encode(\%slot)}++;
    }
    return \@slots;
}
sub calendar_key {
    return join '|', sort map { join ' ', $_->{weekday} // 'n', $_->{hour}, $_->{minute} } @{$_[0]};
}

my $op = shift;
if ($op eq 'near') {
    my ($margin, $clock) = @ARGV;
    my $now = time();
    my $fixture_utc = 0;
    if (length $clock) {
        open my $fh, '<', $clock or exit 2;
        my $line = <$fh> // ''; chomp $line;
        if ($line =~ /\A(\d) (\d+) (\d+)\z/) {
            # Existing fixtures supply a Sunday-based local weekday and an exact minute.
            $now = (3 + $1) * 86400 + $2 * 3600 + $3 * 60;
            $fixture_utc = 1;
        } elsif ($line =~ /\A\d+(?:\.\d+)?\z/) { $now = 0 + $line }
        else { exit 2 }
    }
    my %slots;
    while (<STDIN>) { chomp; $slots{$_} = 1 }
    for (my $at = int($now / 60) * 60; $at < $now + $margin * 60; $at += 60) {
        my @t = $fixture_utc ? gmtime($at) : localtime($at);
        exit 0 if $slots{"n $t[2] $t[1]"} || $slots{"$t[6] $t[2] $t[1]"};
    }
    exit 1;
}
if ($op eq 'capabilities') { print $json->encode({routine_editor => 1}), "\n"; exit }
if ($op eq 'error') { reject(@ARGV) }
if ($op eq 'revision') { print sha256_hex(raw_manifest($ARGV[0])); exit }
if ($op eq 'calendar') {
    my $m = object(raw_manifest($ARGV[0])) or conflict('Repair the malformed routine manifest.');
    print calendar_key(slots($m->{slots}));
    exit;
}
if ($op eq 'description-member') {
    my $m = object(raw_manifest($ARGV[0])) or conflict('Repair the previous manifest.');
    print ',"description":', $json->encode(description($m->{description})) if exists $m->{description};
    exit;
}
if ($op eq 'request') {
    my $change = object($ARGV[0]) or invalid('Pass a JSON object of changed fields.');
    grep(!/\A(slots|description)\z/, keys %$change) and invalid('Only slots and description can change.');
    $change->{slots} = slots($change->{slots}) if exists $change->{slots};
    description($change->{description}) if exists $change->{description};
    print $json->encode($change);
    exit;
}
if ($op eq 'folder-id') {
    my ($dir, $name) = $ARGV[0] =~ m{\A(.*)/([^/]+)\z} or exit 1;
    my @id;
    for ($dir, "$dir/$name") {
        my @st = stat $_;
        exit 1 unless @st && -d _ && -o _ && !-l $_;
        push @id, @st[0, 1];
    }
    print join ':', @id, $name;
    exit;
}
if ($op eq 'plist-hash') {
    my ($path, $limit) = @ARGV;
    exit 1 unless -f $path && -o _ && !-l $path;
    open my $fh, '<:raw', $path or exit 1;
    my $n = read $fh, my $bytes, $limit + 1;
    exit 1 unless defined $n && $n > 0 && $n <= $limit;
    print sha256_hex($bytes);
    exit;
}
if ($op eq 'pending-changes') {
    my ($base, $next) = map { object(raw_manifest($_)) or exit 1 } @ARGV;
    my %changes;
    $changes{slots} = slots($next->{slots})
        if calendar_key(slots($base->{slots})) ne calendar_key(slots($next->{slots}));
    $changes{description} = description($next->{description})
        if ($base->{description} // '') ne ($next->{description} // '');
    print $json->encode(\%changes);
    exit;
}
if ($op eq 'preview') {
    my ($original, $changes) = map { object($_) or exit 1 } @ARGV;
    delete $changes->{description} if exists $changes->{description} &&
        $changes->{description} eq $original->{fields}{description};
    delete $changes->{slots} if exists $changes->{slots} &&
        calendar_key($changes->{slots}) eq calendar_key($original->{fields}{slots});
    $original->{pendingChanges} = $changes;
    print $json->encode($original), "\n";
    exit;
}

if ($op eq 'inspect') {
    my ($file, $name, $expected, $changes) = @ARGV;
    my $bytes = raw_manifest($file);
    my $rev = sha256_hex($bytes);
    my $m = object($bytes) or conflict('Repair the malformed routine manifest.');
    ($m->{source} // '') eq 'adopt' && $json->encode($m->{v}) eq '1'
        or reject('unsupported', 'This producer or manifest version has no Etabli editor.');
    ($m->{name} // '') eq $name && ($m->{label} // '') =~ /\A[A-Za-z0-9._-]{1,200}\z/
        && $m->{label} ne 'com.tonours.fleet-improvement' && ($m->{origin} // '') =~ /\Aplist\.before\.[a-zA-Z0-9_-]+\z/
        or conflict('Repair the routine identity and its saved adoption origin.');
    !$expected || $rev eq $expected or conflict('The manifest changed. Reopen it before saving.');
    my $old = calendar_key(slots($m->{slots}));
    my $desc = exists $m->{description} ? description($m->{description}) : '';
    my $change = object($changes);
    my $new = exists $change->{slots} ? calendar_key($change->{slots}) : $old;
    my $changed = $new ne $old;
    $m->{slots} = $change->{slots} if $changed;
    if (exists $change->{description} && $change->{description} ne $desc) {
        $desc = $m->{description} = $change->{description};
        $changed = 1;
    }
    my $next = $changed ? $json->encode($m) . "\n" : $bytes;
    length($next) <= 8192 or invalid('The resulting manifest exceeds 8192 bytes. Use fewer slots.');
    my $reply = {revision => sha256_hex($next), fields => {slots => slots($m->{slots}), description => $desc}};
    $reply->{status} = $changed ? 'applied' : 'unchanged' if $expected;
    print join("\n", $m->{label}, $m->{origin}, $rev, $old, $new, sha256_hex($next), $json->encode($reply)), "\n";
    print $next if $changed;
    exit;
}

# The editor's environment selects an observation directory. Only the service
# environment (or its GUI account's default home) selects the wrapper's directory.
if ($op eq 'registry') {
    my ($dir, $target, $path, $disk_dir, $disk_home) = @ARGV;
    my ($uid) = $target =~ m{\Agui/(\d+)(?:/[^/]+)?\z} or exit 1;
    local $/;
    my $print = <STDIN>;
    exit 1 unless $print =~ /\A\Q$target\E = \{\n/;
    exit 1 if length($path) && $print !~ /^\tpath = \Q$path\E$/m;
    my %blocks;
    while ($print =~ /^\t([^\n=]*environment) = \{\n(.*?)^\t\}$/msg) {
        my ($block, $entries) = ($1, $2);
        exit 1 unless $block =~ /\A(?:default environment|inherited environment|environment)\z/
            && !exists $blocks{$block};
        my %values;
        for (split /\n/, $entries) {
            /^\t\t([^=\s]+) => ([^\r\n]*)$/ or exit 1;
            exit 1 if exists $values{$1};
            $values{$1} = $2;
        }
        $blocks{$block} = \%values;
    }
    my $headers = () = $print =~ /^\t[^\t\n=]*environment\s*=/mg;
    exit 1 unless keys(%blocks) && keys(%blocks) == $headers;
    my %session = map { %{ $blocks{$_} // {} } } ('default environment', 'inherited environment');
    my %loaded = (%session, %{ $blocks{environment} // {} });
    my %installed = length($path) ? %session : %loaded;
    for ([ETABLI_ROUTINES_DIR => $disk_dir], [HOME => $disk_home]) {
        my ($key, $value) = @$_;
        $installed{$key} = substr($value, 1) if $value ne '-';
    }
    # A service print must agree with the registry selected after reload.
    my @wanted = stat $dir;
    exit 1 unless @wanted;
    for my $env (\%installed, length($path) ? \%loaded : ()) {
        exit 1 if length($env->{BASH_ENV} // '');
        my $home = $env->{HOME} // (getpwuid($uid))[7] // '';
        my $registry = $env->{ETABLI_ROUTINES_DIR};
        $registry = "$home/.claude/state/routines" if !length($registry // '') && $home =~ m{\A/};
        exit 1 unless defined $registry && $registry =~ m{\A/} && $registry !~ /[[:cntrl:]]/;
        my @actual = stat $registry;
        exit 1 unless @actual && $actual[0] == $wanted[0] && $actual[1] == $wanted[1];
    }
    exit;
}

# launchctl print exposes one descriptor per calendar event. Reject unknown
# shapes, extra event sources and incomplete argument lists before any swap.
if ($op eq 'loaded') {
    my ($target, $path, $calendar, @args) = @ARGV;
    my ($label) = $target =~ m{/([^/]+)$};
    local $/;
    my $print = <STDIN>;
    exit 1 unless $print =~ /\A\Q$target\E = \{\n/ && $print =~ /^\tpath = \Q$path\E$/m
        && $print =~ /^\tprogram = \Q$args[0]\E$/m
        && $print =~ /^\targuments = \{\n(.*?)^\t\}$/ms;
    my $arguments = $1;
    exit 1 if grep { /[\r\n]/ } @args;
    exit 1 unless $arguments eq join('', map { "\t\t$_\n" } @args);
    exit 1 unless $print =~ /^\tevent triggers = \{\n(.*?)^\t\}$/ms;
    my $events = $1;
    my @slots;
    while ($events =~ s/\A\s*[^\n]+ => \{\n(.*?)^\t\t\}\n//ms) {
        my $event = $1;
        exit 1 unless $event =~ /^\s*service = \Q$label\E$/m
            && $event =~ /^\s*stream = com\.apple\.launchd\.calendarinterval(?:\.\d+)?$/m
            && $event =~ /^\t\t\tdescriptor = \{\n(.*?)^\t\t\t\}$/ms;
        my %slot;
        for (split /\n/, $1) {
            /^\s*"(Weekday|Hour|Minute)" => (\d+)$/ or exit 1;
            exit 1 if exists $slot{lc $1};
            $slot{lc $1} = 0 + $2;
        }
        push @slots, \%slot;
    }
    exit 1 unless $events =~ /\A\s*\z/ && @slots;
    exit(calendar_key(slots(\@slots)) eq $calendar ? 0 : 1);
}
die "unknown editor operation\n";
