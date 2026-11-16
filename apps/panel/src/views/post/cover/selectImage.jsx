// ** React Imports
import { Fragment, useState } from "react"
// import { Link } from "react-router-dom"
import { useTranslation } from "react-i18next"
import "./style.sass"
// ** Reactstrap Imports
import {
  Card,
  CardFooter,
  Button,
  Modal,
  ModalHeader,
  ModalBody,
  ModalFooter,
  Spinner,
  Row,
  Col
} from "reactstrap"
import { listObjects } from "../../../utility/hooks/useFiles"
import { toast } from "react-toastify"

import { AlertCircle } from "react-feather"

const CoverImage = ({ setCoverLink, coverLink }) => {
  const { t } = useTranslation()

  const [showModal, setShowModal] = useState(false)
  const [loading, setLoading] = useState(false)
  const [images, setImages] = useState([])
  const [allImages, setAllImages] = useState([])
  const [currentPage, setCurrentPage] = useState(1)
  const [pagination, setPagination] = useState(null)
  const [loadingMore, setLoadingMore] = useState(false)
  const [imageLoaded, setImageLoaded] = useState(false)
  const imageExtensions = [".webp"]


  const handleImageLoading = () => {
    setImageLoaded(false)
  }
  const handleImageLoad = () => {
    setImageLoaded(true)
  }

  const getImages = (objects) => {
    if (!objects || !Array.isArray(objects)) {
      return []
    }
    
    return objects.filter((object) => {
      if (!object || !object.name) return false
      const fileExtension = object.name.split(".").pop().toLowerCase()
      return imageExtensions.includes(`.${fileExtension}`)
    })
  }

  const getUserFiles = () => {
    setLoading(true)
    setCurrentPage(1) // Reset to first page
    listObjects((result) => {
      if (result.success) {
        setLoading(false)
        const files = result.data?.files || []
        const paginationData = result.data?.pagination || null
        const imagesList = getImages(files)
        
        setPagination(paginationData)
        setAllImages(imagesList)
        setImages(imagesList)
        
        if (imagesList.length === 0) {
          toast.info("Aucune image WebP trouvée")
        }
      } else {
        setLoading(false)
        console.error("Erreur lors de la récupération des objets:", result.error)
        toast.error("Impossible de charger les images")
        setImages([])
        setAllImages([])
      }
    }, 1, 20)
  }

  const toogleModal = () => {
    getUserFiles()
    setShowModal(true)
  }

  const handleLoadMore = () => {
    if (!pagination?.hasNext) return
    
    setLoadingMore(true)
    const nextPage = currentPage + 1
    
    listObjects((result) => {
      if (result.success) {
        setLoadingMore(false)
        const files = result.data?.files || []
        const paginationData = result.data?.pagination || null
        const newImagesList = getImages(files)
        
        setPagination(paginationData)
        setCurrentPage(nextPage)
        
        // Append new images to existing ones, avoiding duplicates
        const existingImageIds = new Set(allImages.map(image => image.id))
        const uniqueNewImages = newImagesList.filter(image => !existingImageIds.has(image.id))
        const allImagesList = [...allImages, ...uniqueNewImages]
        
        setAllImages(allImagesList)
        setImages(allImagesList)
      } else {
        setLoadingMore(false)
        console.error("Erreur lors du chargement de la page suivante:", result.error)
        toast.error("Impossible de charger plus d'images")
      }
    }, nextPage, 20)
  }

  const save = (imageName) => {
    setShowModal(false)
    setImageLoaded(false)
    setCoverLink('')
    setTimeout(() => {
      setCoverLink(imageName)
    }, 100)
  }

  return (
    <Fragment>
      <Card>
        <div>
          {coverLink && (
            <img
              src={`${coverLink}?w=300`}
              alt=""
              onLoad={handleImageLoad}
              loading={handleImageLoading}
            />
          )}
        </div>
        {coverLink && !imageLoaded && (
          <div className="d-flex flex-column align-items-center justify-content-center my-2">
            <Spinner
              size="lg"
              className="my-2 text-primary"
              style={{ height: "25px", width: "25px" }}
            />
            <span>Loading...</span>
          </div>
        )}
        <CardFooter>
          {t("title.cover_image")}
          <Button color="primary" block className="mb-75" onClick={toogleModal}>
            <span>{t("buttons.choose")}</span>
          </Button>
        </CardFooter>
      </Card>
      <Modal
        isOpen={showModal}
        toggle={() => setShowModal(!showModal)}
        className="modal-dialog modal-xl"
      >
        <ModalHeader toggle={() => setShowModal(!showModal)}>
          {t("fields.select_cover")}
        </ModalHeader>
        <ModalBody className="" style={{ maxHeight: "80vh", overflowY: "auto" }}>
            <div className="thumbnails">
              {loading && (
                <div className="d-flex flex-column align-items-center justify-content-center my-2">
                  <Spinner color="primary" size={"md"} />
                </div>
              )}
              {!loading && images.length === 0 && (
                <div className="d-flex flex-column align-items-center justify-content-center my-2">
                  <AlertCircle size={48} color="red" />
                  <p>Aucun élément trouvé.</p>
                </div>
              )}
                {!loading &&
                  images.length > 0 &&
                  images.map((image) => (
                    <div
                      key={image.name}
                      className={`thumbnail-wrapper ${imageLoaded ? "loaded" : ""}`}
                      style={{ backgroundImage: `url(${image.url}?w=300)`}}
                      onClick={() => {
                        save(`${image.url}`)
                      }}
                    >
                      {!imageLoaded && (
                        <div className="d-flex flex-column align-items-center justify-content-center my-2">
                          <Spinner
                            size="lg"
                            className="my-2 text-primary"
                            style={{ height: "25px", width: "25px" }}
                          />
                          <span>Loading...</span>
                        </div>
                      )}
                      <img
                        src={`${image.url}?w=300`}
                        className={`thumbnail-image ${
                          imageLoaded ? "hidden" : ""
                        }`}
                        style={{ cursor: "pointer" }}
                        alt=""
                        onLoad={handleImageLoad}
                        
                      />
                    </div>

                  ))}

              
            </div>
            {/* Load More Button */}
            {!loading && pagination?.hasNext && (
                <div className="text-center mt-2 mb-2">
                  <Button
                    color="secondary"
                    size="sm"
                    outline
                    onClick={handleLoadMore}
                    disabled={loadingMore}

                  >
                    {loadingMore ? (
                      <>
                        <Spinner size="sm" className="me-2" />
                        Chargement...
                      </>
                    ) : (
                      `Plus`
                    )}
                  </Button>
                </div>
              )}
        </ModalBody>
      </Modal>
    </Fragment>
  )
}

export default CoverImage
