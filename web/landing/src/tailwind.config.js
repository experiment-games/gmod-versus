/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './**/*.{html,js}',
    '!./node_modules/**/*',
  ],
  theme: {
    extend: {
      colors: {
        'logo-blue': '#508CDC',
        'panel': '#141C28',
        'panel-border': '#28374B',
        'panel-deep': '#0A0F16',
      },
    },
    fontFamily: {
      'sans': ['HanSrf', 'Helvetica', 'Arial', 'sans-serif'],
      // Keep default serif and mono
      'serif': ['ui-serif', 'Georgia', 'Cambria', 'Times New Roman', 'Times', 'serif'],
      'mono': ['ui-monospace', 'SFMono-Regular', 'Consolas', 'Liberation Mono', 'Menlo', 'monospace'],
    },
  },
  plugins: [],
}

