import { defineConfig } from "vitest/config";
import { fileURLToPath } from "node:url";

export default defineConfig({
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"],
  },
  resolve: {
    alias: {
      "@tc": fileURLToPath(new URL("./src/modules/tai-chinh", import.meta.url)),
      "@ns": fileURLToPath(new URL("./src/modules/nhan-su", import.meta.url)),
      "@kho": fileURLToPath(new URL("./src/modules/kho", import.meta.url)),
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
});
