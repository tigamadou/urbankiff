import React, { Fragment, useState } from "react"
import { useTranslation } from "react-i18next"
import {
  Button,
  Modal,
  ModalHeader,
  ModalBody,
  ModalFooter,
  Spinner,
  Row,
  Col,
  Card,
  CardBody
} from "reactstrap"
import { AlertCircle, Music, X } from "react-feather"
import { listObjects } from "../../../utility/hooks/useFiles"
import { extractFileNameFromPath } from "../../../utility/Utils"
import { toast } from "react-toastify"
import "../cover/style.sass"

const AudioPlayer = ({ audioLink, setAudioLink }) => {
  const { t } = useTranslation()

  const [showModal, setShowModal] = useState(false)
  const [loading, setLoading] = useState(false)
  const [audios, setAudios] = useState([])
  const audioExtensions = [".mp3", ".wav", ".ogg"]
  const [audioSelected, setAudioSelected] = useState(false)


  const getAudios = (objects) => {
    return objects.filter((object) => {
      const fileExtension = object.name.split(".").pop().toLowerCase()
      return audioExtensions.includes(`.${fileExtension}`)
    })
  }

  const getUserFiles = () => {
    setLoading(true)
    listObjects((result) => {
      if (result.success) {
        setLoading(false)
        const files = result.data?.files || []
        const audiosList = getAudios(files)
        setAudios(audiosList)
      } else {
        setLoading(false)
        console.error("Erreur lors de la récupération des objets:", result.error)
        toast.error("Impossible de charger les fichiers audio")
        setAudios([])
      }
    })
  }

  const selectAudio = (audio) => {
    if (audio === audioLink) {
      setAudioLink(null)
      setAudioSelected(false)
    } else {
      setAudioLink(audio)
      setAudioSelected(true)
    }
  }

  const toogleModal = () => {
    getUserFiles()
    setShowModal(true)
  }

  return (
    <Fragment>
      <Card className="invoice-action-wrapper">
        <CardBody>
          <Row>
            <Col xs="12" md="12" xl="12">
              {audioLink ? (
                <>
                  <div className="d-flex justify-content-center align-items-center">
                    <audio id="audioPlayer" controls>
                      {/* <source src={`${process.env.REACT_APP_IMAGEKIT_ENDPOINT}/${audioLink}`} type="audio/mpeg3" /> */}
                      <source
                        src={`${process.env.REACT_APP_BACKEND_URL}/files/${audioLink}`}
                        type="audio/mpeg"
                      />
                      Your browser does not support the audio element.
                    </audio>
                  </div>
                  <p className="text-center text-primary">
                    {extractFileNameFromPath(audioLink)}
                  </p>
                </>
              ) : (
                <p style={{ fontSize: "12px" }}>
                  {t("messages.no_audio_select")}
                </p>
              )}
            </Col>
            <Col xs="12" md="12" xl="12">
              <div className="d-flex justify-content-between">
                {audioLink ? (
                  <Button
                    color="primary"
                    size="sm"
                    className="mb-75 me-2"
                    onClick={() => setAudioLink("")}
                  >
                    <X />
                  </Button>
                ) : null}
                <Button
                  color="primary"
                  block
                  className="mb-75"
                  onClick={() => toogleModal()}
                >
                  <span>{t("buttons.choose")}</span>
                </Button>
              </div>
            </Col>
          </Row>
        </CardBody>
      </Card>
      <Modal
        isOpen={showModal}
        toggle={() => setShowModal(!showModal)}
        className="modal-dialog modal-lg"
      >
        <ModalHeader className="" toggle={() => setShowModal(!showModal)}>
          {t("fields.audio_link")}
        </ModalHeader>
        <ModalBody className="">
          <div className="files-tiles">
            {loading && audios.length === 0 && (
              <div className="d-flex flex-column align-items-center justify-content-center my-2">
                <Spinner color="primary" size={"md"} />
              </div>
            )}
            {!loading && audios.length === 0 ? (
              <div className="d-flex flex-column align-items-center justify-content-center my-2">
                <AlertCircle size={48} color="red" />
                <p>{t("messages.nothing_found")}</p>
              </div>
            ) : (
              <Row>
                {audios &&
                  audios.map((audio) => (
                    <Col
                      key={audio.name}
                      sm="5"
                      md="5"
                      lg="2"
                      className="text-center mb-2"
                    >
                      <div
                        className="d-flex flex-column justify-content-center align-items-center"
                        onClick={() => selectAudio(audio.name)}
                      >
                        <div
                          className={`${
                            audioLink && audioLink === audio.name ? "selected" : ""
                          }`}
                        >
                          <Music size={30} className="cursor-pointer" />
                          <p className="primary cursor-pointer">
                            {extractFileNameFromPath(audio.name)}
                          </p>
                        </div>
                      </div>
                    </Col>
                  ))}
              </Row>
            )}
          </div>
        </ModalBody>
        <ModalFooter>
          <Button
            color="primary"
            className="mb-75"
            disabled={!audioSelected}
            onClick={() => setShowModal(false)}
          >
            <span>{t("buttons.save")}</span>
          </Button>
        </ModalFooter>
      </Modal>
    </Fragment>
  )
}

export default AudioPlayer
