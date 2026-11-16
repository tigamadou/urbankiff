
import Link from 'next/link';
import PropTypes from 'prop-types';
import React from 'react';

import { ImageWL } from '../ImageWL';
import './PostCard.sass';

const PostCard = ({ post, className }) => {
  const thumb = post.image + '?w=30';
  const large = post.image + '?w=300';
  return (
    <div
      className={`postcard ${className}`}
    >
      <div className="post-image">
        <Link
          href={`/fr/${post.slug}` }
          title={post.title}
        >

          <ImageWL
            className={'ratio_115'}
            title={post.title}
            src={thumb}
            large={large}

          />
        </Link>
      </div>
      <div>

        <Link
          className="title"
          href={`/fr/${post.slug}` }
          title={post.title}
        >
          {post.title}
        </Link>
      </div>

    </div>
  );
};

PostCard.propTypes = {
  post: PropTypes.instanceOf(Object),
  className: PropTypes.string,
};
PostCard.defaultProps = {
  post: null,
  className: '',

  imageRati: '',
};

export default PostCard;
