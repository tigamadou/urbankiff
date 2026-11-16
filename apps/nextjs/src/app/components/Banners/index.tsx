'use client';
import React from 'react';
// import  bannerImage from "@assets/images/banner-1.png";
import Slider from 'react-slick';
import 'slick-carousel/slick/slick.css';
import 'slick-carousel/slick/slick-theme.css';
import './banner.sass';

export default function BannerImage({ images }: { images: []}) {
  const settings = {
    dots: false,
    fade: false,
    infinite: true,
    speed: 500,
    slidesToShow: 1,
    slidesToScroll: 1,
    autoplay: true,
    arrows: false,
    className: 'banner',
  };
  return (
    <div className="banners">
      <div className="banners-content">
        <Slider {...settings}>
          {images.map((image: {title: string, url: string, file: string}) => (
            <div key={image.title}>
              <a href={image.url}>
                <img src={image.file} alt={image.title}/>
              </a>
            </div>

          ))}
        </Slider>
      </div>
    </div>

  );
}
