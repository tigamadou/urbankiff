// ** React Imports
import { useState, Fragment } from "react"

// ** Reactstrap Imports
import {
  Row,
  Col,
  Card,
  Form,
  CardBody,
  CardHeader,
  Button,
  Input,
  Modal,
  Label,
  ModalBody,
  ModalHeader,
  Spinner
} from "reactstrap"

// ** Third Party Components
import Swal from "sweetalert2"
import Select from "react-select"
import { useForm, Controller } from "react-hook-form"
import withReactContent from "sweetalert2-react-content"
import { useTranslation } from "react-i18next"

// ** Custom Components

// ** Utils
import { selectThemeColors } from "@utils"

// ** Styles
import "@styles/react/libs/react-select/_react-select.scss"
import { toast } from "react-toastify"
import { useDispatch } from "react-redux"
import { getUsers } from "../store"
import useFetch from "../../hooks/useFetch"
import { useHistory } from "react-router-dom/cjs/react-router-dom.min"


const statusOptions = [
  { value: "active", label: "Active" },
  { value: "inactive", label: "Inactive" },
  { value: "suspended", label: "Suspended" }
]
const MySwal = withReactContent(Swal)

const UserEditView = ({ selectedUser }) => {
  const { t } = useTranslation()
  // ** State
  const [status, setStatus] = useState(
    selectedUser ? statusOptions[
      statusOptions.findIndex((i) => i.value === selectedUser.status)
    ] : statusOptions[0]
  )
  const [contact, setContact] = useState(selectedUser?.contact || '')
  const [role, setRole] = useState(selectedUser?.role || '')
  const canEdit = selectedUser.isAdmin && selectedUser.id !== selectedUser.id

  // ** Hook
  const {
    reset,
    control,
    // setError,
    handleSubmit,
    formState: { errors }
  } = useForm({
    defaultValues: {
      email: selectedUser?.email || '',
      lastName: selectedUser?.lastname || '',
      firstName: selectedUser?.firstname || ''
    }
  })
  const dispatch = useDispatch()
  const { get: getUserList, put } = useFetch()
  const history = useHistory()


  console.log(selectedUser)

  // ** Show loading state if selectedUser is not available
  if (!selectedUser) {
    return (
      <div className="d-flex justify-content-center align-items-center" style={{ height: '200px' }}>
        <Spinner color="primary" />
      </div>
    )
  }


  const onSubmit = (data) => {
    const payload = {
      role,
      status: status.value,
      email: data.email,
      contact,
      firstname: data.firstName,
      lastname: data.lastName
    }

    const nonEmptyFields = {}

    for (const key in payload) {
      if (payload[key] !== undefined && payload[key] !== null) {
        if (payload[key].length > 0) {
          nonEmptyFields[key] = payload[key]
        }
      }
    }

    put(`/user/${selectedUser.id}`, JSON.stringify(nonEmptyFields))
      .then((res) => {
        if (res.status === 200) {
          toast.success(t("messages.user_updated_successfully"))
          getUserList("/users").then((res) => {
            dispatch(
              getUsers({
                allData: res ? res : []
              })
            )
          })
        }
        history.push("/user/list")
      })
      .catch((err) => console.log(err.message))
  }

  const handleReset = () => {
    reset({
      email: selectedUser.email,
      lastName: selectedUser.lastname,
      firstName: selectedUser.firstname
    })
  }

  const handleBack = () => {
    history.push("/user/list")
  }

  return (
    <Fragment>
      <Card>
        <CardHeader>
          <h4 className="card-title">{t("title.edit_user_information")}</h4>
        </CardHeader>
        <CardBody>
          <div className="">
            <Form onSubmit={handleSubmit(onSubmit)}>
                <Row className="gy-1 pt-75">
                <Col md={6} xs={12}>
                    <Label className="form-label" for="firstName">
                    {t("fields.first_name")}
                    </Label>
                    <Controller
                    defaultValue={selectedUser.firstName}
                    control={control}
                    id="firstName"
                    name="firstName"
                    render={({ field }) => (
                        <Input
                        {...field}
                        id="firstName"
                        placeholder="John"
                        invalid={errors.firstName && true}
                        />
                    )}
                    disabled={!canEdit}
                    />
                </Col>
                <Col md={6} xs={12}>
                    <Label className="form-label" for="lastName">
                    {t("fields.last_name")}
                    </Label>
                    <Controller
                    defaultValue={selectedUser.lastName}
                    control={control}
                    id="lastName"
                    name="lastName"
                    render={({ field }) => (
                        <Input
                        {...field}
                        id="lastName"
                        placeholder="Doe"
                        invalid={errors.lastName && true}
                        />
                    )}
                    disabled={!canEdit}
                    />
                </Col>
                <Col md={6} xs={12}>
                    <Label className="form-label" for="billing-email">
                    {t("fields.email")}
                    </Label>
                    <Input
                    type="email"
                    id="billing-email"
                    disabled
                    defaultValue={selectedUser.email}
                    placeholder="example@domain.com"
                    disabled={!canEdit}
                    />
                </Col>
                <Col md={6} xs={12}>
                    <Label className="form-label" for="status">
                    {t("table.status")}:
                    </Label>
                    <Select
                    id="status"
                    isClearable={false}
                    className="react-select"
                    classNamePrefix="select"
                    options={statusOptions}
                    theme={selectThemeColors}
                    defaultValue={
                        statusOptions[
                        statusOptions.findIndex(
                            (i) => i.value === selectedUser.status
                        )
                        ]
                    }
                    value={status}
                    onChange={setStatus}
                    />
                </Col>

                <Col md={6} xs={12}>
                    <Label className="form-label" for="contact">
                    {t("fields.contact")}
                    </Label>
                    <Input
                    id="contact"
                    value={contact}
                    onChange={(e) => setContact(e.target.value)}
                    placeholder="+1 609 933 4422"
                    />
                </Col>
                <Col md={6} xs={12}>
                    <div className="mb-1">
                    <Label className="form-label" for="user-role">
                        {t("fields.select_user_role")}
                    </Label>
                    <Input
                        type="select"
                        id="user-role"
                        name="user-role"
                        value={role}
                        onChange={(e) => setRole(e.target.value)}
                    >
                        <option value="Subscriber">
                        {t("permissions.subscriber")}
                        </option>
                        <option value="Contributor">
                        {t("permissions.contributor")}
                        </option>
                        <option value="Editor">{t("permissions.editor")}</option>
                        <option value="Administrator">
                        {t("permissions.administrator")}
                        </option>
                    </Input>
                    </div>
                </Col>

                <Col xs={12} className="text-center mt-2 pt-50">
                    <Button type="submit" className="me-1" color="primary">
                    {t("buttons.submit")}
                    </Button>
                    <Button
                    type="reset"
                    color="secondary"
                    outline
                    onClick={() => {
                        handleReset()
                    }}
                    >
                    {t("actions.cancel")}
                    </Button>
                </Col>
                </Row>
            </Form>
            
            <Button
              className="ms-1"
              color="danger"
              outline
              onClick={handleBack}
            >
              {t("buttons.back_to_list")}
            </Button>
          </div>
        </CardBody>
      </Card>
    </Fragment>
  )
}

export default UserEditView
