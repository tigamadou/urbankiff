import { NextResponse } from 'next/server';

export function middleware(request) {
  const url = request.nextUrl.clone();

  // Redirect root route `/` to `/fr`
  if (url.pathname === '/') {
    url.pathname = '/fr';

    return NextResponse.redirect(url);
  }
}
