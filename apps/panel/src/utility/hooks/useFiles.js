import axios from "axios"

function generateUUID() {
    let d = new Date().getTime()
    const uuid = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(
        /[xy]/g,
        function (c) {
            const r = ((d + Math.random()) * 32) % 32 | 0
            d = Math.floor(d / 32)
            return (c === "x" ? r : (r & 0x3) | 0x8).toString(32)
        }
    )
    return uuid
}

const useUploadFile = async  (file, callBack = null) => {
    const formdata = new FormData()
    const fileExtension = file.name.split(".").pop()
    const fileName = `${generateUUID()}.${fileExtension}`
    formdata.append("file", file, fileName)
    const {data, status} = await axios.post("/files/upload", formdata)
    if (status === 201) {
        if (callBack) {
            callBack({
                success: true,
                error: null,
                data,
                fileName,
                originalName: file.name,
                size: file.size,
                type: file.type
            })
        }
    } else {
        if (callBack) {
            callBack({
                success: false,
                error: `Upload failed with status: ${status}`,
                data: null
            })
        }
    }
}


const useDeleteFile = async (file, callBack = null) => {
    try {
        if (!file) {
            if (callBack) {
                callBack({
                    success: false,
                    error: "Missing file parameter",
                    data: null
                })
            }
            return
        }

        const { data, status } = await axios.delete(`file/delete/${file}/`)
        
        if (status === 200) {
            if (callBack) {
                callBack({
                    success: true,
                    error: null,
                    data,
                    deletedFile: file
                })
            }
        } else {
            if (callBack) {
                callBack({
                    success: false,
                    error: `Delete failed with status: ${status}`,
                    data: null
                })
            }
        }
    } catch (error) {
        console.error("Delete error:", error)
        if (callBack) {
            const errorMessage = error.response?.data?.message || error.message || "Delete failed"
            callBack({
                success: false,
                error: errorMessage,
                data: null
            })
        }
    }
}

const listObjects = async (callback, page = 1, pageSize = 20) => {
    try {
        const {data, status} = await axios.get(`files/list?page=${page}&page_size=${pageSize}`)
        if (status === 200) {
            if (callback) {
                callback({
                    success: true,
                    error: null,
                    data
                })
            }
        } else {
            if (callback) {
                callback({
                    success: false,
                    error: `List objects failed with status: ${status}`,
                    data: null
                })
            }
        }
    } catch (error) {
        console.error("List objects error:", error)
        if (callback) {
            const errorMessage = error.response?.data?.message || error.message || "List objects failed"
            callback({
                success: false,
                error: errorMessage,
                data: null
            })
        }
    }
}

const renameFileInUserWorkspace = async (userFolder, oldName, newName, callback) => {
    try {
        if (!userFolder || !oldName || !newName) {
            if (callback) {
                callback({
                    success: false,
                    error: "Missing required parameters: userFolder, oldName, or newName",
                    data: null
                })
            }
            return
        }

        const { data, status } = await axios.put(`file/rename/${userFolder}/${oldName}/${newName}/`)
        
        if (status === 200) {
            if (callback) {
                callback({
                    success: true,
                    error: null,
                    data,
                    oldName,
                    newName,
                    userFolder
                })
            }
        } else {
            if (callback) {
                callback({
                    success: false,
                    error: `Rename failed with status: ${status}`,
                    data: null
                })
            }
        }
    } catch (error) {
        console.error("Rename error:", error)
        if (callback) {
            const errorMessage = error.response?.data?.message || error.message || "Rename failed"
            callback({
                success: false,
                error: errorMessage,
                data: null
            })
        }
    }
}

export {
    useUploadFile,
    useDeleteFile,
    listObjects,
    renameFileInUserWorkspace
}
