import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { token, firstname, lastname, password } = body;

    // Validate required fields
    if (!token || !firstname || !lastname || !password) {
      return NextResponse.json(
        { message: 'Token, firstname, lastname, and password are required' },
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

    const response = await fetch(`${backendUrl}/invitations/accept`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        token,
        firstname,
        lastname,
        password,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      return NextResponse.json(
        { message: data.message || data.error || 'Failed to accept invitation' },
        { status: response.status },
      );
    }

    return NextResponse.json(
      {
        message: 'Invitation accepted successfully',
        token: data.token,
        userId: data.userId,
        user: data.user,
      },
      { status: 200 },
    );

  } catch (error) {
    console.error('Accept invitation API error:', error);
    return NextResponse.json(
      { message: 'Internal server error' },
      { status: 500 },
    );
  }
}

