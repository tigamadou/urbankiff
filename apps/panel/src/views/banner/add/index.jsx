/* eslint-disable no-unused-vars */
// ** Invoice Add Components
import AddCard from "./AddCard"
import AddActions from "./AddActions"

// ** Reactstrap Imports
import { Row, Col, Form } from "reactstrap"
import { toast } from "react-toastify"
// ** Styles
// import "@styles/react/libs/flatpickr/flatpickr.scss"
// import "@styles/base/pages/app-invoice.scss"
import { useState } from "react"
import { useHistory } from "react-router-dom"
import { useTranslation } from "react-i18next"
import axios from "axios"

const PostAdd = () => {
  const [campaignUUID, setCampaignUUID] = useState("")
  const [loading, setLoading] = useState(false)
  const [medias, setMedias] = useState([
    {
      uuid: "",
      type: "picture",
      file: null,
      device: "desktop",
      title: "",
      url: ""
    }
  ])
  const { t } = useTranslation()
  const history = useHistory()

  const createBanner = async () => {
    const data = {
      uuid: campaignUUID,
      medias
    }
    try {
      const response = await axios.post("/ads/", data)
      toast.success(`Campaign saved successfully: ${response.data.uuid}`)
    } catch (error) {
      toast.error(
        `Error saving campaign: ${error.response?.data || error.message}`
      )
    } finally {
      setLoading(false)
      history.push("/banner/list")
    }

    setLoading(false)
  }

  const onHandleSubmit = (e) => {
    e.preventDefault()
    setLoading(true)
    createBanner()
  }
  return (
    <div className="invoice-add-wrapper">
      <Form onSubmit={(e) => onHandleSubmit(e)}>
        <Row className="invoice-add">
          <Col xl={9} md={8} sm={12}>
            <AddCard
              campaignUUID={campaignUUID}
              setCampaignUUID={setCampaignUUID}
              medias={medias}
              setMedias={setMedias}
            />
          </Col>
          <Col xl={3} md={4} sm={12}>
            <AddActions loading={loading} />
          </Col>
        </Row>
      </Form>
    </div>
  )
}

export default PostAdd
