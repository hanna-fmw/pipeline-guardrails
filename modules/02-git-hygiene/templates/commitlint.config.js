/** @type {import('@commitlint/types').UserConfig} */
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'header-max-length': [2, 'always', 72],
    'body-max-line-length': [0, 'always'],
    'type-enum': [
      2,
      'always',
      [
        'feat',     // new user-facing functionality
        'fix',      // bug fix
        'chore',    // dependencies, tooling, config
        'refactor', // no behavior change
        'docs',     // documentation only
        'test',     // tests only
        'perf',     // performance improvement
        'hotfix',   // urgent prod fix (skip non-essential CI)
      ],
    ],
    'subject-case': [2, 'never', ['upper-case', 'pascal-case']],
  },
};
