// Cache configuration for Next.js
export const cacheConfig = {
  // Default cache settings
  default: {
    revalidate: 300, // 5 minutes
    tags: ['default'],
  },

  // High-frequency content (news, posts)
  high: {
    revalidate: 300, // 5 minutes
    tags: ['posts', 'news', 'high-frequency'],
  },

  // Medium-frequency content
  medium: {
    revalidate: 1800, // 30 minutes
    tags: ['medium-frequency'],
  },

  // Low-frequency content (legal pages, static content)
  low: {
    revalidate: 3600, // 1 hour
    tags: ['legal', 'static', 'low-frequency'],
  },

  // Very low-frequency content
  veryLow: {
    revalidate: 86400, // 24 hours
    tags: ['very-low-frequency'],
  },

  // Search results
  search: {
    revalidate: 300, // 5 minutes
    tags: ['search', 'search-results'],
  },

  // Single post content
  singlePost: {
    revalidate: 300, // 5 minutes
    tags: ['posts', 'single-post'],
  },

  // Category content
  category: {
    revalidate: 300, // 5 minutes
    tags: ['posts', 'category'],
  },
};

// Cache tags for invalidation
export const cacheTags = {
  posts: 'posts',
  news: 'news',
  legal: 'legal',
  static: 'static',
  user: 'user',
  search: 'search',
  'search-results': 'search-results',
  'single-post': 'single-post',
  category: 'category',
  musiques: 'musiques',
  cinema: 'cinema',
  videos: 'videos',
  'most-viewed': 'most-viewed',
} as const;

// Helper function to get cache options
export function getCacheOptions(type: keyof typeof cacheConfig = 'default') {
  return cacheConfig[type];
}

// Helper function to create fetch with cache
export async function fetchWithCache(
  url: string,
  options: RequestInit = {},
  cacheType: keyof typeof cacheConfig = 'default',
) {
  const cacheOptions = getCacheOptions(cacheType);

  const response = await fetch(url, {
    ...options,
    next: {
      revalidate: cacheOptions.revalidate,
      tags: cacheOptions.tags,
    },
  });

  return response;
}

// Helper function to revalidate cache by tag
export async function revalidateCache(tag: string) {
  try {
    await fetch(`/api/revalidate?tag=${tag}`, { method: 'POST' });
  } catch (error) {
    console.error(`Failed to revalidate cache for tag: ${tag}`, error);
  }
}
