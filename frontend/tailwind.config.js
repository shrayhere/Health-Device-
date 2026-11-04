/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          dark: '#0A0E17',
          card: '#121824',
          border: '#1F293D',
          cyan: '#00F0FF',
          magenta: '#FF007A',
          green: '#00FF88'
        }
      }
    },
  },
  plugins: [],
}
