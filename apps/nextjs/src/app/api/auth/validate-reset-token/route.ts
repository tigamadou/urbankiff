import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { token, userId } = body;

    // Validate required fields
    if (!token || !userId) {
      return NextResponse.json(
        { message: 'Token and userId are required' },
        { status: 400 },
      );
    }

    // Call the backend API to validate the token
    const backendUrl = process.env.BACKEND_URL || process.env.NEXT_PUBLIC_BACKEND_URL;

    if (!backendUrl) {
      console.error('Backend URL not configured');
      return NextResponse.json(
        { message: 'Server configuration error' },
        { status: 500 },
      );
    }

    const response = await fetch(`${backendUrl}/auth/validate-reset-token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        token,
        userId,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      return NextResponse.json(
        { message: data.message || 'Invalid or expired token' },
        { status: response.status },
      );
    }

    return NextResponse.json(
      { message: 'Token is valid', valid: true },
      { status: 200 },
    );

  } catch (error) {
    console.error('Validate reset token API error:', error);
    return NextResponse.json(
      { message: 'Internal server error' },
      { status: 500 },
    );
  }
}
