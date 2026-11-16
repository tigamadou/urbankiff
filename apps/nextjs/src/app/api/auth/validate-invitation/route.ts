import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { token } = body;

    // Validate required fields
    if (!token) {
      return NextResponse.json(
        { message: 'Token is required' },
        { status: 400 },
      );
    }

    // Call the backend API to validate the invitation token
    // Since there's no direct validation endpoint, we'll try to get invitation details
    // by attempting to validate the token format and checking with the backend
    const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL || process.env.BACKEND_URL;

    if (!backendUrl) {
      console.error('Backend URL not configured');
      return NextResponse.json(
        { message: 'Server configuration error' },
        { status: 500 },
      );
    }

    // We'll validate by trying to accept with minimal data to check if token is valid
    // Actually, a better approach is to check if we can get invitation info
    // For now, we'll return success and let the backend validate on accept
    // But we can make a HEAD request or check token format

    // Since there's no GET endpoint for invitation by token, we'll validate on the accept step
    // For now, just validate token format (UUID)
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(token)) {
      return NextResponse.json(
        { message: 'Invalid invitation token format', valid: false },
        { status: 400 },
      );
    }

    // Token format is valid, but we can't fully validate without backend endpoint
    // The backend will validate when accepting
    return NextResponse.json(
      { message: 'Token format is valid', valid: true },
      { status: 200 },
    );

  } catch (error) {
    console.error('Validate invitation API error:', error);
    return NextResponse.json(
      { message: 'Internal server error' },
      { status: 500 },
    );
  }
}

