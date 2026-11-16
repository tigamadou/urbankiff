'use client';
import PropTypes from 'prop-types';
import React from 'react';
import './imageWL.sass';

const ImageViewer = ({ url }) => (
  <span className="imageWL-previewer" style={{ backgroundImage: `url(${url})` }}/>
);

ImageViewer.propTypes = {
  url: PropTypes.string,
};

ImageViewer.defaultProps = {
  url: null,
};

export { ImageViewer };
