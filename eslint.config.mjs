import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default [
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['**/*.{ts,tsx}'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      'curly': 'error',
    },
  },
  {
    files: ['spec/**/*.ts'],
    rules: {
      '@typescript-eslint/no-wrapper-object-types': 'off',
    },
  },
  { ignores: ['node_modules/', 'example/', 'macos/', '*.config.js'] },
];
