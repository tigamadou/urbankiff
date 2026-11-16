import { initializeApp } from "firebase/app"
import { collection, getFirestore } from "firebase/firestore"
import { getAuth } from 'firebase/auth'

// Firebase n'est plus utilisé : sans REACT_APP_FIREBASE_PROJECT_ID, rien n'est initialisé et les écrans qui en
// dépendent restent inactifs jusqu'à leur portage vers l'api (docs/v1/specs/2026-11-16-publication-depot-public.md, § 9).
export const firebaseActif = Boolean(process.env.REACT_APP_FIREBASE_PROJECT_ID)

const firebaseConfig = {
  apiKey: process.env.REACT_APP_FIREBASE_API_KEY,
  authDomain: process.env.REACT_APP_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.REACT_APP_FIREBASE_PROJECT_ID,
  storageBucket: process.env.REACT_APP_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.REACT_APP_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.REACT_APP_FIREBASE_APP_ID,
  measurementId: process.env.REACT_APP_FIREBASE_MEASUREMENT_ID
}

if (firebaseActif) initializeApp(firebaseConfig)

export const db = firebaseActif ? getFirestore() : null
export const auth = firebaseActif ? getAuth() : null

export const postsRef = db ? collection(db, "posts") : null
export const categoriesRef = db ? collection(db, "categories") : null
export const usersRef = db ? collection(db, "users") : null
export const menusRef = db ? collection(db, "menus") : null
