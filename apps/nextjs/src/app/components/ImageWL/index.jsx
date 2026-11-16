'use client';
import React, { useCallback, useEffect, useRef, useState } from 'react';

import placeholder from '../../assets/images/placeholder.png';

import './imageWL.sass';
import { ImageViewer } from './ImageViewer';


const PlaceHolder = ()=> (
  <ImageViewer url={placeholder} />
);


const ImageWL = ({ src, large, hoverable, title, className, showOriginal  }) => {
  const [isMounted, setIsMounted] = useState(true);
  const imageContainer = useRef(null);
  const imagePreview = useRef(null);
  const imageLoaded = useRef(null);
  const imageOriginalContainter = useRef(null);
  const imageOriginalContainterBlur = useRef(null);
  const imageOriginalContainterImage = useRef(null);

  const loadImage = useCallback(() => {
    const imgLarge = new Image();
    imgLarge.src = large;
    imgLarge.title = title ? title : '';
    imgLarge.alt = title ? title : '';
    imgLarge.onload = function () {
      if (!isMounted){
        return;
      }
      if (imageLoaded.current){
        imageLoaded.current.innerHTML = '';
        imageLoaded.current.appendChild(imgLarge);
        imageLoaded.current.style.backgroundImage= `url(${large})`;
      }
      if (imagePreview.current){
        imagePreview.current.classList.add('hidden');
      }

      setTimeout(()=>{
        if (imagePreview.current && isMounted){
          imagePreview.current.remove();
        }
      }, 1500);
    };
  }, [isMounted, large, title]);
  const loadOriginal = useCallback(() => {
    const imgLarge = new Image();
    imgLarge.src = large;
    imgLarge.title = title ? title : '';
    imgLarge.alt = title ? title : '';
    imageOriginalContainterImage.current.innerHTML ='';
    imgLarge.onload = function () {
      imageOriginalContainterImage.current.innerHTML ='';
      imageOriginalContainterImage?.current?.appendChild(imgLarge);
      imageOriginalContainter.current.style.height = `${imageOriginalContainterImage?.current?.clientHeight}px`;
      imageOriginalContainterImage.current.style.opacity = 1;
    };
  }, [large, title]);

  useEffect(() => {
    if (!isMounted){
      return;
    }
    if (showOriginal){
      if ( imageOriginalContainter && imageOriginalContainter.current){

        loadOriginal();
      }
    }
    if (large){
      loadImage();
    }

  }, [isMounted, showOriginal, large, src, title, loadImage, loadOriginal]);

  useEffect(() => {
    setIsMounted(true);
    return () => {
      setIsMounted(false);
    };
  }, []);


  return (
    <div className={`imageWL ${className} ${hoverable ? 'hoverable' : ''}`}>
      {!showOriginal ?
        <div className="imageWL-container" ref={imageContainer}>
          <div className="imageWL-loaded " ref={imageLoaded}/>
          <div className="imageWL-preview" ref={imagePreview} >
            { src ?
              <ImageViewer url={src} />
              :
              <PlaceHolder/>
            }
          </div>

        </div>
        :
        <>
          { large &&
            <div className="imageWL-orignal-container" ref={imageOriginalContainter}>
              <div className="imageWL-orignal-blur" style={{ backgroundImage: `url(${src})` }} ref={imageOriginalContainterBlur}></div>
              <div className="imageWL-orignal-image" ref={imageOriginalContainterImage}></div>
            </div>
          }
        </>

      }
    </div>
  );
};


ImageWL.defaultProps = {
  src: null,
  large: null,
  hoverable: null,
  title: null,
  className: '',
  showOriginal: false,
};


export { ImageWL };
