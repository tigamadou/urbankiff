import { LeftOutlined, RightOutlined } from '@ant-design/icons';
import Link from 'next/link';
import React from 'react';

import './pagination.sass';

interface PaginationProps {
    currentPage: number; // The current active page
    totalPages: number; // The total number of pages
    basePath: string; // The base URL for the pagination links
}

const Pagination: React.FC<PaginationProps> = ({ currentPage, totalPages, basePath }) => {
  const generatePageLinks = () => {
    const pages = [];
    const maxVisiblePages = 7; // Maximum number of page numbers to show

    if (totalPages <= maxVisiblePages) {
      // If total pages is small, show all pages
      for (let i = 1; i <= totalPages; i++) {
        pages.push({ page: i, type: 'number' });
      }
    } else {
      // Always show first page
      pages.push({ page: 1, type: 'number' });

      if (currentPage <= 4) {
        // Show pages 1, 2, 3, 4, 5, ..., totalPages
        for (let i = 2; i <= 5; i++) {
          pages.push({ page: i, type: 'number' });
        }
        pages.push({ page: '...', type: 'ellipsis' });
        pages.push({ page: totalPages, type: 'number' });
      } else if (currentPage >= totalPages - 3) {
        // Show pages 1, ..., totalPages-4, totalPages-3, totalPages-2, totalPages-1, totalPages
        pages.push({ page: '...', type: 'ellipsis' });
        for (let i = totalPages - 4; i <= totalPages; i++) {
          pages.push({ page: i, type: 'number' });
        }
      } else {
        // Show pages 1, ..., currentPage-1, currentPage, currentPage+1, ..., totalPages
        pages.push({ page: '...', type: 'ellipsis' });
        for (let i = currentPage - 1; i <= currentPage + 1; i++) {
          pages.push({ page: i, type: 'number' });
        }
        pages.push({ page: '...', type: 'ellipsis' });
        pages.push({ page: totalPages, type: 'number' });
      }
    }

    return pages;
  };

  const isFirstPage = currentPage === 1;
  const isLastPage = currentPage === totalPages;

  const previousLink = () => (<Link className={`pagination-prev ${
    currentPage === 1 ? 'pagination-disabled' : ''
  }`} href={`${basePath}?page=${currentPage - 1}`} passHref>
    <LeftOutlined/>
  </Link>);

  const previousLinkDisabled = () => (<span className='pagination-prev pagination-disabled'>
    <LeftOutlined/>
  </span>);

  const previiousLinkLogic = (disabled: boolean) => {
    if(disabled){
      return previousLinkDisabled();
    }
    return previousLink();
  };

  const nextLink = () => (<Link className={`pagination-next ${
    currentPage === totalPages ? 'pagination-disabled' : ''
  }`} href={`${basePath}?page=${currentPage + 1}`} passHref>
    <RightOutlined/>
  </Link>);

  const nexLinkDisabled = () => (<span className='pagination-next pagination-disabled'>
    <RightOutlined/>
  </span>);

  const nextLinkLogic = (disabled: boolean) => {
    if(disabled){
      return nexLinkDisabled();
    }
    return nextLink();
  };

  return (
    <div className="pagination">
      {previiousLinkLogic(isFirstPage)}
      <ul className="pagination-container">
        {/* Page Links */}
        {generatePageLinks().map((item, index) => (
          <li key={index}>
            {item.type === 'ellipsis' ? (
              <span className="pagination-ellipsis">
                {item.page}
              </span>
            ) : (
              <Link
                className={`pagination-item pagination-item-${item.page} ${
                  item.page === currentPage ? 'pagination-item-active' : ''
                }`}
                href={`${basePath}?page=${item.page}`}
                passHref
              >
                {item.page}
              </Link>
            )}
          </li>
        ))}
      </ul>
      {nextLinkLogic(isLastPage)}
    </div>
  );
};

export default Pagination;
