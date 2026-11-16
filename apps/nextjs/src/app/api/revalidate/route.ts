import { revalidateTag, revalidatePath } from 'next/cache';
import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const tag = searchParams.get('tag');
    const path = searchParams.get('path');

    if (tag) {
      revalidateTag(tag);
    }

    if (path) {
      revalidatePath(path);
    }

    if (!tag && !path) {
      return NextResponse.json(
        { error: 'Missing tag or path parameter' },
        { status: 400 },
      );
    }

    return NextResponse.json({
      revalidated: true,
      now: Date.now(),
      tag,
      path,
    });
  } catch (error) {
    console.error('Cache revalidation error:', error);
    return NextResponse.json(
      { error: 'Failed to revalidate cache' },
      { status: 500 },
    );
  }
}

export async function GET() {
  return NextResponse.json({
    message: 'Cache revalidation endpoint',
    usage: 'POST /api/revalidate?tag=posts&path=/fr/musiques',
    availableTags: [
      'posts', 'news', 'legal', 'static', 'user', 'search', 'search-results',
      'single-post', 'category', 'musiques', 'cinema', 'videos', 'most-viewed',
      'high-frequency', 'medium-frequency', 'low-frequency', 'very-low-frequency',
    ],
    examples: [
      'POST /api/revalidate?tag=posts',
      'POST /api/revalidate?tag=musiques',
      'POST /api/revalidate?tag=search-results',
      'POST /api/revalidate?path=/fr/musiques',
      'POST /api/revalidate?tag=posts&path=/fr/cinema',
    ],
  });
}
