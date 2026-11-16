import React, { useState } from "react"
import "./image.sass"
import { Button, Spinner, Badge } from "reactstrap"
import Sidebar from "@components/sidebar"
import {
    extractFileNameFromPath,
    formatFileSize,
    getFileType
} from "../../../../utility/Utils"
import { Copy, Trash, Video, Music, FileText, Image } from "react-feather"
import { toast } from "react-toastify"
import moment from "moment"
import { EditableInput } from "./editFilename"

const FileLibrary = ({
    image,
    onDelete,
    loading,
    setLoading,
    handleSaveFileName,
    loadingEdit
}) => {
    const formattedLastModified = moment(image.LastModified).format(
        "MMM D YYYY, h:mm A"
    )
    const thumbnailImgUrl = `${image.url}?w=300`
    const ImageUrl = `${image.url}`
    const [imageLoaded, setImageLoaded] = useState(false)
    const [sidebarOpen, setSidebarOpen] = useState(false)
    const fileType = getFileType(image.name)

    const handleImageLoad = () => {
        setImageLoaded(true)
    }

    const toggleSidebar = () => {
        setSidebarOpen(!sidebarOpen)
    }

    const onCopyLink = () => {
        // Fallback copy function for better browser compatibility
        const copyToClipboard = async (text) => {
            try {
                // Try modern clipboard API first
                if (navigator.clipboard && window.isSecureContext) {
                    await navigator.clipboard.writeText(text)
                    return true
                } else {
                    // Fallback for older browsers or non-HTTPS
                    const textArea = document.createElement('textarea')
                    textArea.value = text
                    textArea.style.position = 'fixed'
                    textArea.style.left = '-999999px'
                    textArea.style.top = '-999999px'
                    document.body.appendChild(textArea)
                    textArea.focus()
                    textArea.select()
                    
                    try {
                        document.execCommand('copy')
                        textArea.remove()
                        return true
                    } catch (err) {
                        textArea.remove()
                        return false
                    }
                }
            } catch (err) {
                return false
            }
        }

        copyToClipboard(ImageUrl).then(success => {
            if (success) {
                toast.success("Lien copié avec succès")
            } else {
                toast.error("Impossible de copier le lien")
            }
        })
    }

    const onClosed = () => {
        setLoading(false)
        setSidebarOpen(false)
    }

    const renderFileThumbnail = () => {
        switch (fileType) {
            case "image":
                return (
                    <div
                        onClick={toggleSidebar}
                        className={`thumbnail-wrapper ${imageLoaded ? "loaded" : ""}`}
                        style={{ backgroundImage: `url(${thumbnailImgUrl})`}}
                    >
                        {!imageLoaded && (
                            <div className="d-flex flex-column align-items-center justify-content-center">
                                <Spinner
                                    size="sm"
                                    className="my-2 text-primary"
                                    style={{ height: "25px", width: "25px" }}
                                />
                            </div>
                        )}
                        <img
                            src={`${thumbnailImgUrl}`}
                            className={`thumbnail-image ${
                                imageLoaded ? "hidden" : ""
                            }`}
                            alt=""
                            onLoad={handleImageLoad}
                            
                        />
                    </div>
                )
            case "video":
                return (
                    <div className="thumbnail-wrapper">
                        <Video
                            size={100}
                            className="thumbnail-image"
                            onClick={toggleSidebar}
                        />
                        <div style={{ fontSize: "10px" }}>
                            <strong>{extractFileNameFromPath(image.name)}</strong>
                        </div>
                    </div>
                )
            case "music":
                return (
                    <div className="thumbnail-wrapper">
                        <Music
                            size={100}
                            className="thumbnail-image"
                            onClick={toggleSidebar}
                        />
                        <div style={{ fontSize: "10px" }}>
                            <strong>{extractFileNameFromPath(image.name)}</strong>
                        </div>
                    </div>
                )

            default:
                return (
                    <div className="thumbnail-wrapper">
                        <FileText
                            size={100}
                            className="thumbnail-image"
                            onClick={toggleSidebar}
                        />
                        <div style={{ fontSize: "10px" }}>
                            <strong>{extractFileNameFromPath(image.name)}</strong>
                        </div>
                    </div>
                )
        }
    }

    const renderFileContent = () => {
        switch (fileType) {
            case "image":
                return (
                    <img src={`${thumbnailImgUrl}`} alt="" onLoad={handleImageLoad} />
                )
            case "video":
                return (
                    <div className="thumbnail-wrapper">
                        <Video size={100} />
                        <div style={{ fontSize: "12px" }}>
                            <strong>
                                {extractFileNameFromPath(image.name)}
                            </strong>
                        </div>
                    </div>
                )
            case "music":
                return (
                    <div className="thumbnail-wrapper">
                        <Music size={100} />
                        <div style={{ fontSize: "12px" }}>
                            <strong>
                                {extractFileNameFromPath(image.name)}
                            </strong>
                        </div>
                    </div>
                )

            default:
                return (
                    <div className="thumbnail-wrapper">
                        <FileText size={100} />
                        <div style={{ fontSize: "12px" }}>
                            <strong>
                                {extractFileNameFromPath(image.name)}
                            </strong>
                        </div>
                    </div>
                )
        }
    }

    const getFileTypeIcon = () => {
        switch (fileType) {
            case "image":
                return <Image size={16} />
            case "video":
                return <Video size={16} />
            case "music":
                return <Music size={16} />

            default:
                return <FileText size={16} />
        }
    }

    const getFileTypeLabel = () => {
        switch (fileType) {
            case "image":
                return "Image"
            case "video":
                return "Vidéo"
            case "music":
                return "Musique"

            default:
                return "Document"
        }
    }

    return (
        <>
            {renderFileThumbnail()}
            <Sidebar
                size="sm"
                open={sidebarOpen}
                title={
                    <div className="d-flex align-items-center">
                        {getFileTypeIcon()}
                        <span className="ms-2">{getFileTypeLabel()}</span>
                        <Badge color="primary" className="ms-2">
                            {fileType.toUpperCase()}
                        </Badge>
                    </div>
                }
                headerClassName="mb-1"
                contentClassName="pt-0"
                toggleSidebar={toggleSidebar}
                onClosed={onClosed}
            >
                {/* File Preview Section */}
                <div className="file-preview-section mb-4">
                    <div className="preview-container">
                        {renderFileContent()}
                    </div>
                </div>
                
                {/* File Information Section */}
                <div className="file-info-section mb-4">
                    <div className="section-header mb-3">
                        <h6 className="text-primary mb-0">
                            <strong>📋 Informations du fichier</strong>
                        </h6>
                    </div>
                    
                    <div className="info-grid">
                        <div className="info-row">
                            <span className="info-label">Nom du fichier:</span>
                            <div className="info-value">
                                <EditableInput
                                    initialValue={extractFileNameFromPath(image.name)}
                                    onSave={handleSaveFileName}
                                    loading={loadingEdit}
                                />
                            </div>
                        </div>
                        
                        <div className="info-row">
                            <span className="info-label">Taille:</span>
                            <span className="info-value">
                                <Badge color="secondary" className="px-2 py-1">
                                    {formatFileSize(image.size)}
                                </Badge>
                            </span>
                        </div>
                        
                        <div className="info-row">
                            <span className="info-label">Modifié le:</span>
                            <span className="info-value text-muted">
                                {formattedLastModified}
                            </span>
                        </div>
                        
                        <div className="info-row">
                            <span className="info-label">Type:</span>
                            <span className="info-value">
                                <Badge color="info" className="px-2 py-1">
                                    {fileType.toUpperCase()}
                                </Badge>
                            </span>
                        </div>
                    </div>
                </div>

                {/* File Actions Section */}
                <div className="file-actions-section mb-4">
                    <div className="section-header mb-3">
                        <h6 className="text-primary mb-0">
                            <strong>🔗 Actions</strong>
                        </h6>
                    </div>
                    
                    <div className="link-section mb-3">
                        <div className="d-flex align-items-center justify-content-between">
                            <span className="info-label">Lien direct:</span>
                            <Button
                                color="outline-primary"
                                onClick={onCopyLink}
                                size="sm"
                                title="Copier le lien"
                                className="copy-btn"
                            >
                                <Copy size={14} className="me-1" />
                                Copier
                            </Button>
                        </div>
                        <div className="link-display mt-2">
                            <a
                                href={ImageUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="file-link"
                            >
                                {ImageUrl}
                            </a>
                        </div>
                    </div>
                </div>
                
                {/* Danger Zone Section */}
                <div className="danger-zone-section">
                    <div className="section-header mb-3">
                        <h6 className="text-danger mb-0">
                            <strong>⚠️ Zone de danger</strong>
                        </h6>
                    </div>
                    
                    <div className="danger-content">
                        <div className="warning-message mb-3">
                            <p className="text-muted small mb-2">
                                <strong>Attention:</strong> Cette action est irréversible et supprimera définitivement le fichier.
                            </p>
                        </div>
                        
                        {loading ? (
                            <div className="loading-state d-flex align-items-center justify-content-center">
                                <Spinner size="sm" className="me-2 text-danger" />
                                <span className="text-danger">Suppression en cours...</span>
                            </div>
                        ) : (
                            <div className="delete-action">
                                <Button
                                    color="danger"
                                    onClick={() => onDelete(image.name)}
                                    size="sm"
                                    outline
                                    className="w-100"
                                >
                                    <Trash size={16} className="me-2" />
                                    Supprimer définitivement
                                </Button>
                            </div>
                        )}
                    </div>
                </div>
            </Sidebar>
        </>
    )
}

export { FileLibrary }
