import fs from "fs";
import dotenv from "dotenv";

// Load environment variables from the `.env` file
dotenv.config();

// Path to the generated `env.mo` file
const envMoPath = "./src/AxiaSystem_backend/env.mo";

// Extract all environment variables from `.env`
const envVariables = process.env;

// Generate the Motoko `env.mo` module content
let motokoContent = `module {\n`;
for (const [key, value] of Object.entries(envVariables)) {
  if (key.startsWith("CANISTER_ID_")) {
    const motokoKey = key.toLowerCase().replace("canister_id_", "canister_id_");
    motokoContent += `    public let ${motokoKey}: Text = "${value}";\n`;
  }
}
motokoContent += `}\n`;

// Write the Motoko file
fs.writeFileSync(envMoPath, motokoContent, "utf8");
console.log(`Generated ${envMoPath}`);