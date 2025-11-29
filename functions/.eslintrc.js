module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "quotes": ["error", "double"],
    // Satır uzunluğu sınırını kaldırıyoruz (Hata vermez)
    "max-len": "off",
    // Girinti hatasını kapatıyoruz (Prettier vs. ile çakışmaması için)
    "indent": "off",
    "object-curly-spacing": "off",
    "comma-dangle": "off",
    "require-jsdoc": "off",
    "valid-jsdoc": "off",
    "no-tabs": "off",
    "no-trailing-spaces": "off",
    "eol-last": "off",
  },
  parserOptions: {
    ecmaVersion: 2018, // veya 8
  },
};