const fs = require("fs");

const readSecret = (envVar) => {
  const val = process.env[envVar];
  if (!val) return null;
  // If the value looks like a file path (Docker secrets), read from file
  try {
    if (val.startsWith("/run/secrets/") || val.startsWith("/")) {
      return fs.readFileSync(val).toString("utf8").trim();
    }
  } catch (_) {}
  return val;
};

module.exports = {
  database: {
    host: process.env.DATABASE_HOST || "localhost",
    port: process.env.DATABASE_PORT || 3306,
    database: process.env.DATABASE_DB,
    user: process.env.DATABASE_USER,
    password: readSecret("DATABASE_PASSWORD"),
  },
  port: process.env.PORT || 8080,
};
