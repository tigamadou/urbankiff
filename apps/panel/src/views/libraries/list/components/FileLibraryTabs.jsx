import React, { useState, useMemo, useEffect } from "react"
import { Nav, NavItem, NavLink, TabContent, TabPane, Badge, Card, CardBody, Button } from "reactstrap"
import { Image, Video, Music, FileText } from "react-feather"
import { getFileType } from "../../../../utility/Utils"
import { FileLibrary } from "./FileLibrary"
import classnames from "classnames"
import "./FileLibraryTabs.sass"

const FileLibraryTabs = ({
    files,
    onDelete,
    loading,
    setLoading,
    handleSaveFileName,
    onLoadMore,
    loadingMore,
    hasMore
}) => {
    const [activeTab, setActiveTab] = useState("image")

    // Group files by type
    const groupedFiles = useMemo(() => {
        const groups = {
            image: [],
            video: [],
            music: [],
            other: []
        }

        files.forEach(file => {
            const fileType = getFileType(file.name)
            if (groups[fileType]) {
                groups[fileType].push(file)
            } else {
                groups.other.push(file)
            }
        })

        return groups
    }, [files])

    // Get tab configuration
    const tabs = [
        {
            id: "image",
            label: "Images",
            icon: <Image size={16} />,
            count: groupedFiles.image.length,
            color: "success"
        },
        {
            id: "video",
            label: "Vidéos",
            icon: <Video size={16} />,
            count: groupedFiles.video.length,
            color: "warning"
        },
        {
            id: "music",
            label: "Musique",
            icon: <Music size={16} />,
            count: groupedFiles.music.length,
            color: "info"
        },
        {
            id: "other",
            label: "Documents",
            icon: <FileText size={16} />,
            count: groupedFiles.other.length,
            color: "dark"
        }
    ]

    const toggleTab = (tabId) => {
        if (activeTab !== tabId) {
            setActiveTab(tabId)
        }
    }

    const renderTabContent = (tabId) => {
        const allFilesOfType = groupedFiles[tabId] || []
        const filesToShow = allFilesOfType
        
        if (allFilesOfType.length === 0) {
            return (
                <div className="text-center py-5">
                    <div className="mb-3">
                        {tabs.find(tab => tab.id === tabId)?.icon}
                    </div>
                    <h6 className="text-muted">Aucun fichier trouvé</h6>
                    <p className="text-muted small">
                        {tabId === "image" ? "Aucune image WebP trouvée" : `Aucun fichier de type "${tabs.find(tab => tab.id === tabId)?.label}" trouvé`}
                    </p>
                </div>
            )
        }

        return (
            <>
                <div className="thumbnails">
                    {filesToShow.map((file) => (
                        <FileLibrary
                            key={file.name}
                            image={file}
                            loading={loading}
                            setLoading={setLoading}
                            onDelete={onDelete}
                            handleSaveFileName={handleSaveFileName}
                        />
                    ))}
                </div>
                
                {/* Load More Button - only show if there are more files available */}
                {hasMore && (
                    <div className="text-center mt-4">
                        <Button
                            onClick={onLoadMore}
                            disabled={loadingMore}
                            type="text"
                            outline
                            loading={loadingMore}
                        >
                            {loadingMore ? (
                                "Chargement..."
                            ) : (
                                `Plus`
                            )}
                        </Button>
                    </div>
                )}
            </>
        )
    }
    useEffect(() => {
        console.log({files})
    }, [])
    return (
        <Card className="file-library-tabs">
            <CardBody className="p-0">
                {/* Tab Navigation */}
                <Nav tabs className="border-bottom">
                    {tabs.map((tab) => (
                        <NavItem key={tab.id}>
                            <NavLink
                                className={classnames(
                                    "d-flex align-items-center gap-2 px-1 py-1",
                                    { active: activeTab === tab.id }
                                )}
                                onClick={() => toggleTab(tab.id)}
                                style={{ cursor: "pointer" }}
                            >
                                {tab.icon && <span className="me-0">{tab.icon}</span>}
                                <span>{tab.label}</span>
                                <Badge 
                                    color={tab.color} 
                                    className="ms-auto"
                                    style={{ fontSize: "0.75rem" }}
                                >
                                    {tab.count}
                                </Badge>
                            </NavLink>
                        </NavItem>
                    ))}
                </Nav>

                {/* Tab Content */}
                <TabContent activeTab={activeTab} className="p-1">
                    {tabs.map((tab) => (
                        <TabPane key={tab.id} tabId={tab.id}>
                            {renderTabContent(tab.id)}
                        </TabPane>
                    ))}
                </TabContent>
            </CardBody>
        </Card>
    )
}

export { FileLibraryTabs }
