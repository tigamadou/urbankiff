import React, { useState } from 'react'
import { Edit2, Save, Cancel } from 'react-feather'
import * as Icon from 'react-feather'
import { Button, Input, Spinner } from 'reactstrap'

function EditableInput({ initialValue, onSave, loading }) {
  const [isEditing, setIsEditing] = useState(false)
  const [value, setValue] = useState(initialValue)
  const oldName = initialValue

  const handleEditClick = () => {
    setIsEditing(true)
  }

  const handleSaveClick = () => {
    onSave(oldName, value)
    setIsEditing(false)
  }
  

  return (
    <div className='mb-1'>
      {isEditing ? (
        <div>
          <div className="mb-1">
            <Input
              type='text'
              value={value}
              onChange={(e) => setValue(e.target.value)}
            />
          </div>
          <div className='d-flex gap-1'>
            <Button
              onClick={handleSaveClick}
              color="success"
              size='sm'
            >Save
            </Button>
            <Button
              onClick={() => setIsEditing(false)}
              size='sm'
              color="danger"
              outline
            >Cancel
            </Button>
          </div>
        </div>
      ) : (
        <div>
          <p style={{ fontSize: '12px' }}>{value}
            {!loading ? (
              <Button
                color="none"
                onClick={handleEditClick}
                size='sm'>
                <Edit2 className='rounded' />
              </Button>
            ) : (
              <Spinner
                size="sm"
                className="text-primary"
                style={{ height: "15px", width: "15px" }}
              />)}
          </p>
        </div>
      )}
    </div>
  )
}

export { EditableInput }
