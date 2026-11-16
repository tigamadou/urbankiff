import React, { Fragment } from "react"
import { useDispatch } from "react-redux"
import { toast } from "react-toastify"
import { Button, Modal, ModalHeader, ModalBody, ModalFooter } from "reactstrap"
import { getBanners } from "../store"
import useFetch from "../../hooks/useFetch"
import { useTranslation } from "react-i18next"

export default function DeleteModal(props) {
  const dispatch = useDispatch()
  const { t } = useTranslation()
  const { destroy, get } = useFetch()
  const onHandleDelete = (e) => {
    e.preventDefault()
    destroy(`/ads/${props.row.id}`).then(() => {
      get("/ads/").then((res) => {
        if (res) {
          dispatch(
            getBanners({
              allData: res,
              total: res.length
            })
          )
        }
        toast.error(t("messages.banner_deleted"))
        props.setModal(!props.modal)
      })
    })
  }
  return (
    <Fragment>
      <Modal
        isOpen={props.modal}
        toggle={() => props.setModal(!props.modal)}
        className={`modal-dialog-centered`}
      >
        <ModalHeader toggle={() => props.setModal(!props.modal)}>
          {t("actions.deleting_banner")}
        </ModalHeader>
        <ModalBody>
          <span className="bold">{t("messages.confirm")}</span>
        </ModalBody>
        <ModalFooter>
          <Button color="primary" onClick={(e) => onHandleDelete(e)} outline>
            {t("actions.confirm")}
          </Button>
          <Button color="danger" onClick={() => props.setModal(!props.modal)}>
            {t("actions.cancel")}
          </Button>
        </ModalFooter>
      </Modal>
    </Fragment>
  )
}
