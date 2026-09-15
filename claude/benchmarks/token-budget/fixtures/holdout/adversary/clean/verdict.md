Reviewer verdict: BLOCK — SQL injection in src/user.ts: the query is built
from the raw `name` argument interpolated into the SQL string, so an attacker
controls the statement. Must use parameterized queries.
