import axios from "axios"
import React from "react"
import AsyncCreatableSelect from "react-select/async-creatable"
import { selectThemeColors } from '@utils'
const Tags = ({tags, setTags}) => {

  const filterTags = (options, inputValue) => {
    const filtered =  options.filter((i) => i.name.toLowerCase().includes(inputValue.toLowerCase())
    )
    return filtered.map((tag) => ({ value: tag.id, label: tag.name }))
  }
  const loadOptions = async (inputValue) => {
    const {data, status} = await axios.get("/post/tags")
    if (status === 200) {
        return filterTags(data, inputValue)
    }
  }
  const createTag = async (tagName) => {
    try {
      const response = await axios.post("/post/tags", { name: tagName })
      return { value: response.data.id, label: response.data.name }
    } catch (error) {
      console.error('Error creating tag:', error)
      return null
    }
  }
  const handleCreate = async (inputValue) => {
    const newTag = await createTag(inputValue)
    if (newTag) {
      setTags((prevTags) => [...prevTags, newTag]) // Add the new tag to the local state
    }
  }

  return (
    <AsyncCreatableSelect
      id="blog-edit-category"
      isClearable={false}
      isMulti
      name="colors"
      className="react-select"
      classNamePrefix="select"
      theme={selectThemeColors}
      value={tags}
      onChange={(data) => setTags(data)}
      cacheOptions
      defaultOptions
      loadOptions={loadOptions}
      placeholder="Select or create tags..."
      onCreateOption={handleCreate}
    />
  )
}

export default Tags
