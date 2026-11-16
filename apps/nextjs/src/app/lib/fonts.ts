import { Roboto } from 'next/font/google';

// Roboto font configuration
export const roboto = Roboto({
  subsets: ['latin'],
  weight: ['100', '300', '400', '500', '700', '900'],
  style: ['normal', 'italic'],
  display: 'swap',
  variable: '--font-roboto',
  preload: true,
  fallback: ['-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', 'sans-serif'],
});

// Font variables for CSS
export const fontVariables = {
  roboto: roboto.variable,
};

// Font classes for components
export const fontClasses = {
  roboto: roboto.className,
};
