// ** React Imports
import { Fragment } from "react"

import {
  Row,
  Col,
  Card,
  Form,
  Input,
  Label,
  Button,
  CardBody,
  CardText,
  CardHeader,
  Spinner
} from "reactstrap"
import Repeater from '@components/repeater'
import { X, Plus } from 'react-feather'
import { SlideDown } from 'react-slidedown'

// ** Styles
import 'react-slidedown/lib/slidedown.css'
// import '@styles/react/libs/react-select/_react-select.scss'
// import '@styles/react/libs/flatpickr/flatpickr.scss'
// import '@styles/base/pages/app-invoice.scss'
// ** Third Party Components

// ** Styles
import "@styles/react/libs/editor/editor.scss"
import { useTranslation } from "react-i18next"
import CoverImage from "../cover/selectImage"

const AddCard = ({
    medias, setMedias, campaignUUID,
    setCampaignUUID, loading
}) => {
  const handleMediaChange = (e, index, field) => {
    const newMedias = [...medias]
    newMedias[index][field] = e.target.value
    setMedias(newMedias)
  }
  const handleMediaFileChange = (file, index, field) => {
    const newMedias = [...medias]
    newMedias[index][field] = file
    setMedias(newMedias)
  }
  const addMedia = () => {
    setMedias([
      ...medias,
      { uuid: '', type: 'picture', file: '', device: 'desktop', title: '', url: '' }
    ])
  }
  const removeMedia = (index) => {
    const newMedias = medias.filter((_, i) => i !== index)
    setMedias(newMedias)
  }
  const types = [
    {
        label: 'Picture',
        key: 'picture'
      }, {
        label: 'Video',
        key: 'video'
      }
    ]
    const devices = [
      {
          label: 'Desktop',
          key: 'desktop'
        },
        {
          label: 'Tablet',
          key: 'tablet'
        },
        {
          label: 'Mobile',
          key: 'mobile'
        }
      ]

  const { t } = useTranslation()

  return (
    <Fragment>
      <Card className="invoice-preview-card">
      <CardHeader>
        <h4 className='card-title'>Add a Banner</h4>
      </CardHeader>
        <CardBody className="py-2">
        <Row className="mb-10">
          <Col md={12} className='mb-md-0 mb-5'>
              <Label className='form-label'>
                Campaign Name
              </Label>
              <Input type='text' placeholder='Enter The Campaign Name' value={campaignUUID} onChange={e => setCampaignUUID(e.target.value)} />
          </Col>
        </Row>
        <div className="mt-2 mb-1">
          <h4>Campaign Medias</h4>
        </div>
        <Repeater count={medias.length}>
          {i => {
            const Tag = i === 0 ? 'div' : SlideDown
            return (
              <Tag key={i}>
                <Form>
                  <Row>
                  <Col md={4} className='mb-md-0 mb-1'>
                      <Label className='form-label' for={`animation-item-name-${i}`}>
                        Name
                      </Label>
                      <Input type='text' id={`animation-item-name-${i}`} placeholder='Enter Banner Name' value={medias[i].uuid}  onChange={(e) => handleMediaChange(e, i, 'uuid')} />
                  </Col>
                  <Col md={4}>
                    <div className="mb-1">
                      <Label>Type</Label>
                      <Input
                        type="select"
                        name="select"
                        id="select-basic-language"
                        disabled={loading}
                        required
                        value={medias[i].type}  onChange={(e) => handleMediaChange(e, i, 'type')}
                      >
                        <option disabled value="">
                          {t("fields.choose_language")}
                        </option>
                        {Array.isArray(types) &&
                          types.map(({label, key}) => (
                            <option key={key} value={key}>
                              {label}
                            </option>
                          ))}
                      </Input>
                    </div>
                    </Col>
                    <Col md={4}>
                    <div className="mb-1">
                      <Label>Devices</Label>
                      <Input
                        type="select"
                        name="select"
                        id="select-basic-language"
                        disabled={loading}
                        required
                        value={medias[i].device}  onChange={(e) => handleMediaChange(e, i, 'device')}
                      >
                        <option disabled value="">
                          {t("fields.choose_language")}
                        </option>
                        {Array.isArray(devices) &&
                          devices.map(({label, key}) => (
                            <option key={key} value={key}>
                              {label}
                            </option>
                          ))}
                      </Input>
                    </div>
                    </Col>
                  </Row>
                  <Row className="h-60 d-flex items-center justify-center">
                  <Col md={6} className='mb-md-0 mb-1'>
                      <Label className='form-label' for={`animation-item-name-${i}`}>
                        Url
                      </Label>
                      <Input type='text' id={`animation-item-name-${i}`} placeholder='Enter Banner Url' value={medias[i].url}  onChange={(e) => handleMediaChange(e, i, 'url')} />
                  </Col>
                    <Col md={6}>
                    <div style={{width: "80%"}}>
                    <CoverImage setCoverLink={(file) => handleMediaFileChange(file, i, 'file')} coverLink={medias[i].file} />
                    </div>
                    </Col>
                  </Row>
                  <Row>
                  <Col md={4}>
                      <Button color='danger' className='text-nowrap px-1' onClick={() => removeMedia(i)} outline>
                        <X size={14} className='me-50' />
                        <span>Delete</span>
                      </Button>
                    </Col>
                    <Col sm={12}>
                      <hr />
                    </Col>
                  </Row>
                </Form>
              </Tag>
            )
          }}
        </Repeater>
        <Button className='btn-icon' color='primary' onClick={() => addMedia()}>
          <Plus size={14} />
          <span className='align-middle ms-25'>Add New</span>
        </Button>
        </CardBody>
      </Card>
    </Fragment>
  )
}

export default AddCard
