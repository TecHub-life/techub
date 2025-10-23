/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: 'class',
  content: [
    './app/views/**/*.{erb,html,html.erb}',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.{js,ts}',
    './config/initializers/**/*.rb',
  ],
  safelist: [
    // Ensure arbitrary aspect-ratio utilities used via ERB interpolation are generated
    'aspect-[16/9]', // card, simple
    'aspect-[1200/630]', // og
    'aspect-[3/1]', // banner
    'aspect-[1/1]', // x_profile_400, fb_post_1080
    'aspect-[4/5]', // ig_portrait_1080x1350
  ],
}
