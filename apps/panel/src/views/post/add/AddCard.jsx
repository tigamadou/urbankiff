// ** React Imports
import { Fragment, useEffect, useState } from "react"

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

// ** Styles
// import 'react-slidedown/lib/slidedown.css'
// import '@styles/react/libs/react-select/_react-select.scss'
// import '@styles/react/libs/flatpickr/flatpickr.scss'
// import '@styles/base/pages/app-invoice.scss'
// ** Third Party Components

import { Editor } from "react-draft-wysiwyg"

// ** Styles
import "@styles/react/libs/editor/editor.scss"
import slugify from "react-slugify"
import useFetch from "../../hooks/useFetch"
import { useTranslation } from "react-i18next"
import Tags from "./Tags"

const AddCard = ({
  category,
  setCategory,
  title,
  setTitle,
  intro,
  setIntro,
  content,
  setContent,
  loading,
  lang,
  setLang,
  tags,
  setTags
}) => {
  const [categories, setCategories] = useState([])

  const languages = [
  {
      label: 'Français',
      key: 'fr'
    }, {
      label: 'English',
      key: 'en'
    }
  ]
  const { get: getCategoriesList } = useFetch()
  const { t } = useTranslation()

  //** States */
  useEffect(() => {
    getCategoriesList("/category/").then((res) => {
      if (res) {
        setCategories(res)
      }
    })
  }, [])
  const handleCategory = (event) => {
    const category = categories.filter(
      (item) => item.name === event.target.value
    )
    setCategory(category[0])
  }

  const handleLanguage = (event) => {
    setLang(event.target.value)
  }
  return (
    <Fragment>
      <Card className="invoice-preview-card">
        <CardBody className="py-2">
          <h4>{t("title.post")} </h4>
          <Row>
            <div className="mb-1">
              <Label>{t("fields.language")}</Label>
              <Input
                type="select"
                name="select"
                id="select-basic-language"
                onChange={handleLanguage}
                value={lang}
                disabled={loading}
                required
              >
                <option disabled value="">
                  {t("fields.choose_language")}
                </option>
                {Array.isArray(languages) &&
                  languages.map(({label, key}) => (
                    <option key={key} value={key}>
                      {label}
                    </option>
                  ))}
              </Input>
            </div>
            <div className="mb-1">
              <Label className="form-label" for="select-basic">
                {t("fields.select_post_category")}
              </Label>
              <Input
                type="select"
                name="select"
                id="select-basic"
                onChange={handleCategory}
                value={category?.name}
                disabled={loading}
                required
              >
                {categories.length > 0 &&
                  categories.map((item) => (
                    <option key={item.id}>{item.name}</option>
                  ))}
              </Input>
            </div>
            <div className="mb-1">
              <Label>{t("fields.title")}</Label>
              <Input
                type="text"
                name="title"
                onChange={(e) => setTitle(e.target.value)}
                value={title}
                required
                disabled={loading}
              />
            </div>

            <div className="mb-1">
              <Label>Url</Label>
              <Input type="text" name="title" value={slugify(title)} disabled />
            </div>

            <div className="mb-1">
              <Label>{t("fields.description")}</Label>
              <Input
                type="textarea"
                name="intro"
                onChange={(e) => setIntro(e.target.value)}
                value={intro}
                required
                disabled={loading}
              />
            </div>

            
            <div className="mb-2">
              <Label tag="h6">{t("fields.tags")}</Label>
              <Tags tags={tags} setTags={setTags} />
            </div>

            <div className="mb-1">
              <Label tag="h6">{t("fields.content")}</Label>
              <Editor
                editorState={content}
                onEditorStateChange={(data) => setContent(data)}
                disabled={loading}
              />
            </div>
          </Row>
        </CardBody>
      </Card>
    </Fragment>
  )
}

export default AddCard
