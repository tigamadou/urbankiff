import './assets/style/index.sass';
import { GoogleAnalytics } from '@next/third-parties/google';
import Script from 'next/script';

import { roboto } from './lib/fonts';

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr" className={roboto.variable}>
      <body className={roboto.className}>
        <GoogleAnalytics gaId="G-NFJEL91108" />
        <Script
          async
          src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-6589571705906525"
          crossOrigin="anonymous"
          strategy="afterInteractive"
        />
        {children}
      </body>
    </html>
  );
}
