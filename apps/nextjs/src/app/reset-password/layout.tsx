import { ConfigProvider } from 'antd';

import { roboto } from '../lib/fonts';

export default function ResetPasswordLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr" className={roboto.variable}>
      <body className={roboto.className}>
        <ConfigProvider
          wave={{ disabled: true }}
        >
          <div className="reset-password-layout">
            {children}
          </div>
        </ConfigProvider>
      </body>
    </html>
  );
}
