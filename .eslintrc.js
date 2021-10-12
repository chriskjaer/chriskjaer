module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:react/recommended',
    'plugin:react-hooks/recommended',
    'next',
    'plugin:jsx-a11y/recommended',
    'plugin:prettier/recommended', // Make sure this is always the last element in the array.
  ],
  env: {
    browser: true,
    node: true,
  },
  settings: {
    react: {
      version: 'detect',
    },
  },
  rules: {
    'prettier/prettier': ['error', {}, { usePrettierrc: true }],
    'react/react-in-jsx-scope': 'off',
    'react/prop-types': 'off',
    '@typescript-eslint/explicit-function-return-type': 'off',
    '@typescript-eslint/explicit-module-boundary-types': 'off',

    // Don't use null. The TS Team don't and it works fine for them.
    // See:
    // https://basarat.gitbook.io/typescript/recap/null-undefined#final-thoughts
    // https://github.com/Microsoft/TypeScript/wiki/Coding-guidelines#null-and-undefined
    '@typescript-eslint/ban-types': [
      'error',
      {
        types: {
          null: "Use 'undefined' instead of 'null'",
        },
      },
    ],

    'simple-import-sort/imports': 'error',
    'no-null/no-null': 'error',
    'jsx-a11y/anchor-is-valid': [
      'error',
      {
        components: ['Link'],
        specialLink: ['hrefLeft', 'hrefRight'],
        aspects: ['invalidHref', 'preferButton'],
      },
    ],
  },
  plugins: ['@typescript-eslint', 'simple-import-sort', 'no-null'],
}
