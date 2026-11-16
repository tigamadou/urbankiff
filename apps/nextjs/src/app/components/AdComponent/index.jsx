'use client';
import axios from 'axios';
import PropTypes from 'prop-types';
import React, { useCallback, useEffect, useState } from 'react';

import BannerImage from '../Banners';
// import useScreenBreakpoint from "@/hooks/useScreenBreakpoint"

/**
 * AdComponent displays advertisements based on the provided space UUID.
 * It fetches ad data, selects the appropriate ad space, and renders either
 * a single banner or a slider of banners depending on the number of associated media.
 *
 * @component
 * @example
 * // Example usage of AdComponent
 * <AdComponent space_uuid="campaign_main" />
 *
 * @param {Object} props - Component properties.
 * @param {string} props.space_uuid - The UUID for the ad space to fetch and render.
 * @returns {JSX.Element} - Rendered advertisement component.
 */
const AdComponent = ({ space_uuid }) => {
  /**
   * The currently selected ad space object to render.
   * @type {Object|null}
   */
  const [adToRender, setAdToRender] = useState(null);

  /**
   * List of all ad spaces fetched from the server.
   * @type {Array<Object>}
   */
  const [adSpaces, setAdSpaces] = useState([]);

  /**
   * Loading state to indicate whether the component is fetching data.
   * @type {boolean}
   */
  const [loading, setLoading] = useState(false);

  /**
   * Current screen size detected via the useScreenBreakpoint hook.
   * @type {string}
   */
  // const { screenSize } = useScreenBreakpoint()

  /**
   * Fetches the ad space data based on the provided space_uuid.
   * If the UUID does not match any ad space, defaults to the first ad space.
   */
  const fetchAd = useCallback(() => {
    const adSpace =
      adSpaces.find(({ uuid }) => uuid === space_uuid) || adSpaces[0];
    setAdToRender(adSpace || null);
  }, [adSpaces, space_uuid]);

  /**
   * Fetches the list of ad spaces from the server.
   * Updates the adSpaces state with the fetched data.
   */
  const getBanners = useCallback(async () => {
    try {
      setLoading(true);
      const { status, data } = await axios.get(`${process?.env?.NEXT_PUBLIC_BACKEND_URL || process?.env?.BACKEND_URL}/ads/`);
      if (status === 200) {
        setAdSpaces(data);
      }
    } catch (error) {
      console.error('Error fetching banners:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  /**
   * Renders a slider containing multiple media items.
   *
   * @param {Array<Object>} medias - The media items to display in the slider.
   * @returns {JSX.Element} - Rendered slider component.
   */
  const renderSlider = (medias) => <BannerImage images={medias} />;

  /**
   * Renders a single banner for a single media item.
   *
   * @param {Object} media - The media object to render.
   * @param {string} media.url - The URL the banner links to.
   * @param {string} media.title - The title of the banner.
   * @param {string} media.file - The image source URL of the banner.
   * @returns {JSX.Element} - Rendered single banner component.
   */
  const renderOneBanner = (media) => (
    <div className="add-container">
      <div className="add">
        <a href={media.url} title={media.title}>
          <img alt={media.title} src={media.file} />
        </a>
      </div>
    </div>
  );

  /**
   * Determines whether to render a slider or a single banner
   * based on the number of media items in the selected ad space.
   *
   * @returns {JSX.Element|null} - Rendered ad component or null if no media is available.
   */
  const renderLogic = () => {
    const { medias } = adToRender || {};
    if (!medias || medias.length === 0) {return null;}
    return medias.length > 1 ? renderSlider(medias) : renderOneBanner(medias[0]);
  };

  /**
   * useEffect to fetch banners from the server whenever the space_uuid changes.
   */
  useEffect(() => {
    getBanners();
  }, [space_uuid, getBanners]);

  /**
   * useEffect to select the ad space to render whenever the adSpaces list is updated.
   */
  useEffect(() => {
    fetchAd();
  }, [adSpaces, fetchAd]);

  /**
   * useEffect to log the current screen size whenever it changes.
   */

  /**
   * Returns null while data is loading, or renders the selected ad space.
   */
  if (loading) {
    return null; // Optionally replace with a loading spinner or skeleton UI.
  }

  return <div>{adToRender && renderLogic()}</div>;
};

/**
 * Prop types for the AdComponent.
 *
 * @typedef {Object} AdComponentProps
 * @property {string} space_uuid - The UUID of the ad space to render.
 */
AdComponent.propTypes = {
  space_uuid: PropTypes.string,
};

/**
 * Default props for the AdComponent.
 *
 * @type {AdComponentProps}
 */
AdComponent.defaultProps = {
  space_uuid: null,
};

export { AdComponent };
