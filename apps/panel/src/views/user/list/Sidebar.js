// ** React Import
import { useState } from "react"

// ** Custom Components
import Sidebar from "@components/sidebar"

// ** Utils

// ** Third Party Components
import { useForm, Controller } from "react-hook-form"

// ** Reactstrap Imports
import { Button, Label, FormText, Form, Input, Spinner, Alert } from "reactstrap"

// ** Store & Actions
import { toast } from "react-toastify"
import { useTranslation } from "react-i18next"
import axios from "axios"

const checkIsValid = (data) => {
  return (
    Object.values(data).every((field) => (typeof field === "object" ? field !== null : field.length > 0)
    ) || Object.values(data).every((field) => field !== null)
  )
}

const SidebarNewUsers = ({ open, toggleSidebar, user }) => {
  const defaultValues = {
    email: user ? user.email : ""
  }
  // ** States
  const [role, setRole] = useState(user ? user.role : "Administrator")
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  // ** Store Vars
  const { t } = useTranslation()

  // ** Vars
  const {
    control,
    setValue,
    handleSubmit,
    formState: { errors }
  } = useForm({ defaultValues })

  // ** Function to handle form submit
  const onSubmit = async (data) => {
    if (checkIsValid(data)) {
      const payload = {
        role,
        email: data.email
      }

      setLoading(true)
      setError(null)

      try {
        const response = await axios.post("/invitations/send", payload)
        if (response.status === 201 || response.status === 200) {
          toast.success(t("messages.user_added_successfully"))
          toggleSidebar()
          setLoading(false)
        }
      } catch (err) {
        const errorMessage = err.response?.data?.message || err.message || t("messages.error_occurred")
        toast.error(errorMessage)
        setLoading(false)
        setError(errorMessage)
      }
    } else {
      toast.error(t("messages.fill_fields_correctly"))
    }
  }

  const handleSidebarClosed = () => {
    for (const key in defaultValues) {
      setValue(key, "")
    }
    setRole("")
    setError(null)
    setLoading(false)
  }

  return (
    <Sidebar
      size="lg"
      open={open}
      title={t("title.new_user")}
      headerClassName="mb-1"
      contentClassName="pt-0"
      toggleSidebar={toggleSidebar}
      onClosed={handleSidebarClosed}
    >
      <Form onSubmit={handleSubmit(onSubmit)}>
        {error && (
          <Alert color="danger" className="mb-2">
            {error}
          </Alert>
        )}
        
        <div className="mb-1">
          <Label className="form-label" for="userEmail">
            {t("fields.email")} <span className="text-danger">*</span>
          </Label>
          <Controller
            name="email"
            control={control}
            render={({ field }) => (
              <Input
                type="email"
                id="userEmail"
                disabled={user || loading}
                placeholder="john.doe@example.com"
                invalid={errors.email && true}
                {...field}
              />
            )}
          />
        </div>

        <div className="mb-1">
          <Label className="form-label" for="user-role">
            {t("fields.user_role")}
          </Label>
          <Input
            type="select"
            id="user-role"
            name="user-role"
            value={role}
            onChange={(e) => setRole(e.target.value)}
            disabled={loading}
          >
            <option value="" selected hidden>
              {t("fields.select_user_role")}
            </option>
            <option value="Subscriber">{t("permissions.subscriber")}</option>
            <option value="Contributor">{t("permissions.contributor")}</option>
            <option value="Editor">{t("permissions.editor")}</option>
            <option value="Administrator">
              {t("permissions.administrator")}
            </option>
          </Input>
        </div>
        <Button 
          type="submit" 
          className="me-1" 
          color="primary"
          disabled={loading}
        >
          {loading ? (
            <>
              <Spinner size="sm" className="me-1" />
              {t("buttons.submit") || "Submitting..."}
            </>
          ) : (
            t("buttons.submit")
          )}
        </Button>
        <Button 
          type="reset" 
          color="secondary" 
          outline 
          onClick={toggleSidebar}
          disabled={loading}
        >
          {t("actions.cancel")}
        </Button>
      </Form>
    </Sidebar>
  )
}

export default SidebarNewUsers
