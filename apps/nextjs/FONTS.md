# Font System Documentation

## Overview
This project uses Next.js 15's built-in font optimization system for optimal performance and SEO.

## Font Configuration

### Roboto Font
- **Source**: Google Fonts (optimized via Next.js)
- **Weights**: 100, 300, 400, 500, 700, 900
- **Styles**: Normal, Italic
- **Subsets**: Latin

## Implementation

### 1. Font Configuration (`src/app/lib/fonts.ts`)
```typescript
import { Roboto } from 'next/font/google'

export const roboto = Roboto({
  subsets: ['latin'],
  weight: ['100', '300', '400', '500', '700', '900'],
  style: ['normal', 'italic'],
  display: 'swap',
  variable: '--font-roboto',
  preload: true,
  fallback: ['-apple-system', 'BlinkMacSystemFont', 'Segoe UI', ...],
})
```

### 2. Layout Integration (`src/app/layout.tsx`)
```typescript
import { roboto } from './lib/fonts'

export default function RootLayout({ children }) {
  return (
    <html lang="fr" className={roboto.variable}>
      <body className={roboto.className}>
        {children}
      </body>
    </html>
  )
}
```

### 3. CSS Variables (`src/app/globals.css`)
```css
:root {
  --font-roboto: 'Roboto', -apple-system, BlinkMacSystemFont, ...;
  --font-weight-light: 300;
  --font-weight-regular: 400;
  --font-weight-medium: 500;
  --font-weight-semibold: 600;
  --font-weight-bold: 700;
  --font-weight-black: 900;
}
```

## Usage

### In SASS/CSS
```sass
body
  font-family: var(--font-roboto)
  font-weight: var(--font-weight-regular)

.title
  font-weight: var(--font-weight-bold)
  font-size: var(--font-size-2xl)
```

### In Components
```typescript
import { fontClasses } from '@/lib/fonts'

<div className={fontClasses.roboto}>
  This text uses Roboto font
</div>
```

### Utility Classes
```html
<div class="font-roboto font-bold text-2xl">
  Bold Roboto Text
</div>
```

## Benefits

1. **Performance**: Fonts are preloaded and optimized
2. **SEO**: Better Core Web Vitals scores
3. **User Experience**: No layout shifts during font loading
4. **Maintainability**: Centralized font configuration
5. **Fallbacks**: Robust fallback font stack

## Best Practices

1. **Always use CSS variables** for font families
2. **Use utility classes** for common font weights
3. **Keep font configuration centralized** in `lib/fonts.ts`
4. **Avoid importing fonts in SASS/CSS files**
5. **Use semantic font weight variables** instead of hardcoded values

## Adding New Fonts

1. Add font configuration to `lib/fonts.ts`
2. Import in `layout.tsx`
3. Add CSS variables to `globals.css`
4. Create utility classes if needed
