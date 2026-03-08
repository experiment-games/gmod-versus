/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './*.html',
    './svgs/*.html',
    './script.js',
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/typography'),
  ],
}
