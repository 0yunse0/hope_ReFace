module.exports = {
  root: true,
  env: {
    es2021: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2021, // optional chaining, nullish coalescing 등 허용
    sourceType: "module",
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "linebreak-style": "off",
    "quotes": "off",
    "eol-last": ["warn", "always"],
    "object-curly-spacing": ["warn", "always"],
    "max-len": ["warn", { code: 120, ignoreStrings: true, ignoreTemplateLiterals: true }],
    "indent": ["warn", 2, { SwitchCase: 1 }],
    "comma-dangle": ["warn", "only-multiline"],
    "no-multi-spaces": "warn",

    "require-jsdoc": "off",
    "valid-jsdoc": "off",
    "new-cap": ["warn", { capIsNew: false }], // express.Router() 허용
    "guard-for-in": "off"
  },
};
