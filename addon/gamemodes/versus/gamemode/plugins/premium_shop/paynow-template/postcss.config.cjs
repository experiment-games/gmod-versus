module.exports = {
  plugins: [
    require('tailwindcss'),
    require('postcss-nesting'),
    require('autoprefixer'),
    ...(process.env.NODE_ENV === 'production' ? [require('cssnano')({ preset: 'default' })] : []),
  ],
}
