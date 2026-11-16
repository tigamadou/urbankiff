import React, { useState, useEffect, useRef } from "react"
import {
  listObjects,
  renameFileInUserWorkspace,
  useDeleteFile,
  useUploadFile
} from "../../../utility/hooks/useFiles"
import {
  Spinner,
  Button,
  Card,
  CardBody,
  CardHeader
} from "reactstrap"
import { useDispatch, useSelector } from "react-redux"
import { getLibraries } from "../store"
import { toast } from "react-toastify"
import { FileLibraryTabs } from "./components/FileLibraryTabs"
import { UploadFileComponent } from "./components/UploadFile"
import { AlertCircle, RefreshCw } from "react-feather"

const MediaLibraryView = () => {
  const [loading, setLoading] = useState(false)
  const [loadingUploadFile, setloadingUploadFile] = useState(false)
  const dispatch = useDispatch()
  const store = useSelector((state) => state.libraries)
  const userInfo = useSelector((state) => state.auth.userData)
  const fileInputRef = useRef(null)
  const [selectedFile, setSelectedFile] = useState(null)
  const [fileIsSelected, setFileIsSelected] = useState(false)
  const [loadingOnDelete, setLoadingOnDelete] = useState(false)

  const [updateObjects, setUpdateObjects] = useState(0)
  const [currentPage, setCurrentPage] = useState(1)
  const [pagination, setPagination] = useState(null)
  const [loadingMore, setLoadingMore] = useState(false)
  // File Upload  modal
  const [show, setShow] = useState(false)

  useEffect(() => {
    setLoading(true)
    setCurrentPage(1) // Reset to first page
    listObjects((result) => {
      if (result.success) {
        setLoading(false)
        const files = result.data?.files || []
        const paginationData = result.data?.pagination || null
        
        setPagination(paginationData)
        
        // Remove duplicates from initial load (in case of race conditions)
        const uniqueFiles = files.filter((file, index, self) => index === self.findIndex(f => f.id === file.id))
        
        dispatch(
          getLibraries({
            data: uniqueFiles,
            total: paginationData?.totalCount || uniqueFiles.length
          })
        )
      } else {
        setLoading(false)
        console.error("Erreur lors de la récupération des objets:", result.error)
        toast.error("Failed to load media library")
      }
    }, 1, 20)
  }, [dispatch, updateObjects])

  const handleLoadMore = () => {
    if (!pagination?.hasNext) return
    
    setLoadingMore(true)
    const nextPage = currentPage + 1
    
    listObjects((result) => {
      if (result.success) {
        setLoadingMore(false)
        const newFiles = result.data?.files || []
        const paginationData = result.data?.pagination || null
        
        setPagination(paginationData)
        setCurrentPage(nextPage)
        
        // Append new files to existing ones, avoiding duplicates
        const existingFileIds = new Set(store.data.map(file => file.id))
        const uniqueNewFiles = newFiles.filter(file => !existingFileIds.has(file.id))
        const allFiles = [...store.data, ...uniqueNewFiles]
        
        dispatch(
          getLibraries({
            data: allFiles,
            total: paginationData?.totalCount || allFiles.length
          })
        )
      } else {
        setLoadingMore(false)
        console.error("Erreur lors du chargement de la page suivante:", result.error)
        toast.error("Failed to load more files")
      }
    }, nextPage, 20)
  }

  const handleFileChange = (event) => {
    const file = event.target.files[0]
    if (file) {
      setFileIsSelected(true)
      setSelectedFile(file)
    } else {
      setFileIsSelected(false)
    }
  }

  const onUploadFile = () => {
    if (!selectedFile) {
      toast.error("Please select a file to upload")
      return
    }

    setloadingUploadFile(true)
    useUploadFile(selectedFile, (result) => {
      if (result.success) {
        toast.success(`File "${result.originalName}" uploaded successfully!`)
        setloadingUploadFile(false)
        setShow(false)
        setSelectedFile(null)
        setFileIsSelected(false)
        setUpdateObjects(updateObjects + 1)
        
        // Reset file input
        if (fileInputRef.current) {
          fileInputRef.current.value = ""
        }
      } else {
        const errorMessage = result.error || "Failed to upload your file"
        toast.error(errorMessage)
        setloadingUploadFile(false)
        
        // Keep the file selected so user can try again
        console.error("Upload failed:", result.error)
      }
    })
  }

  const onDelete = (image) => {
    const confirmDelete = window.confirm(
      "Êtes-vous sûr de vouloir supprimer ce fichier ?"
    )
    if (confirmDelete) {
      setLoadingOnDelete(true)
      useDeleteFile(image, (result) => {
        if (result.success) {
          setLoadingOnDelete(false)
          toast.success(`File "${result.deletedFile}" deleted successfully`)
          setUpdateObjects(updateObjects + 1)
        } else {
          setLoadingOnDelete(false)
          const errorMessage = result.error || "Failed to delete your file"
          toast.error(errorMessage)
          console.error("Delete failed:", result.error)
        }
      })
    } else {
      toast.info("Cancelled successfully")
    }
  }
  const handleSaveFileName = (oldName, newName) => {
    renameFileInUserWorkspace(`user_${userInfo.userId}`, oldName, newName, (result) => {
      if (result.success) {
        setUpdateObjects(updateObjects + 1)
        setDisplayedItems(100) // Reset to initial count
        toast.success(`File "${result.oldName}" renamed to "${result.newName}" successfully`)
      } else {
        setUpdateObjects(updateObjects + 1)
        const errorMessage = result.error || "Could not rename file"
        toast.error(errorMessage)
        console.error("Rename failed:", result.error)
      }
    })
  }

  return (
    <Card>
      <CardHeader className="bg-light">
        <div className="d-flex justify-content-between">
          <h5>Ma Bibliothèque Multimédia</h5>
        </div>
        <div style={{ display: "flex", gap: 12 }}>
          <Button.Ripple
            className="btn-icon rounded-circle"
            outline
            color="primary"
            onClick={() => {
              setUpdateObjects(updateObjects + 1)
            }}
            size="xs"
          >
            <RefreshCw />
          </Button.Ripple>
          <UploadFileComponent
            show={show}
            setShow={setShow}
            showModal={() => setShow(true)}
            handleFileChange={handleFileChange}
            fileIsSelected={fileIsSelected}
            onUploadFile={onUploadFile}
            loading={loadingUploadFile}
            fileInputRef={fileInputRef}
          />
        </div>
      </CardHeader>
      <CardBody style={{ paddingTop: "1.5rem" }}>
        <div className="mb-5">
        {loading && (
            <div className="d-flex flex-column align-items-center justify-content-center my-2">
              <Spinner
                size="lg"
                className="me-25 my-2 text-primary"
                style={{ height: "50px", width: "50px" }}
              />
              <span>Chargement en cours...</span>
            </div>
          )}
          {!loading && store.data.length === 0 && (
            <div className="d-flex flex-column align-items-center justify-content-center my-2">
              <AlertCircle size={48} color="red" />
              <p>Aucun élément trouvé.</p>
            </div>
          )}

          {!loading && store.data.length > 0 && (
            <FileLibraryTabs
              files={store.data}
              loading={loadingOnDelete}
              setLoading={setLoadingOnDelete}
              onDelete={onDelete}
              handleSaveFileName={handleSaveFileName}
              onLoadMore={handleLoadMore}
              loadingMore={loadingMore}
              hasMore={pagination?.hasNext || false}
            />
          )}
        </div>
      </CardBody>
    </Card>
  )
}

export default MediaLibraryView
