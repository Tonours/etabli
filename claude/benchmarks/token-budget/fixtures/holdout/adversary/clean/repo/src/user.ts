import { query } from "./db.js";

export function findUser(name: string) {
	return query("SELECT id, name FROM users WHERE name = $1", [name]);
}
