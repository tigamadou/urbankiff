import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { token, userId, password } = body;

    // Validate required fields
    if (!token || !userId || !password) {
      return NextResponse.json(
        { message: 'Token, userId, and password are required' },
        { status: 400 },
      );
    }

    // Validate password strength
    if (password.length < 8) {
      return NextResponse.json(
        { message: 'Password must be at least 8 characters long' },
        { status: 400 },
      );
    }

    // Call the backend API
    const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL || process.env.BACKEND_URL;

    if (!backendUrl) {
      console.error('Backend URL not configured');
      return NextResponse.json(
        { message: 'Server configuration error' },
        { status: 500 },
      );
    }

    const response = await fetch(`${backendUrl}/auth/reset-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        token,
        userId,
        password,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      return NextResponse.json(
        { message: data.message || 'Failed to reset password' },
        { status: response.status },
      );
    }

    return NextResponse.json(
      { message: 'Password reset successfully' },
      { status: 200 },
    );

  } catch (error) {
    console.error('Reset password API error:', error);
    return NextResponse.json(
      { message: 'Internal server error' },
      { status: 500 },
    );
  }
}
