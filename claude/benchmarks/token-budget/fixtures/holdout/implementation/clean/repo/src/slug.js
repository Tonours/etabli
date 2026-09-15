function slugify(value) {
	return String(value)
		.normalize("NFD")
		.replace(/[\u0300-\u036f]/g, "")
		.toLowerCase()
		.trim()
		.replace(/[\s_]+/g, "-")
		.replace(/^-+|-+$/g, "");
}

module.exports = { slugify };
