import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Perch Care - App Store Screenshots",
  description: "App Store screenshot generator for Perch Care",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh" className="h-full antialiased">
      <body
        className="min-h-full flex flex-col"
        style={{
          fontFamily:
            '"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans SC", -apple-system, BlinkMacSystemFont, sans-serif',
        }}
      >
        {children}
      </body>
    </html>
  );
}
