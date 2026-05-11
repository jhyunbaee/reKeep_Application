import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  // Firebase 콘솔의 설정값 입력
  apiKey: "YOUR_API_KEY",
  authDomain: "rekeep.firebaseapp.com",
  projectId: "rekeep",
  storageBucket: "rekeep.appspot.com",
  messagingSenderId: "...",
  appId: "...",
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
