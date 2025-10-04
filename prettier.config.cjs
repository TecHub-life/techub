module.exports = {
  printWidth: 100,
  singleQuote: true,
  semi: false,
  trailingComma: 'es5',
  plugins: ['prettier-plugin-tailwindcss', '@prettier/plugin-xml'],
  overrides: [
    {
      files: ['*.json', '*.md', '*.yml', '*.yaml'],
      options: {
        proseWrap: 'always',
      },
    },
  ],
}
