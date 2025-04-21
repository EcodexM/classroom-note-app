// Firebase SDK Imports
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.8.1/firebase-app.js";
import {
  getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut, onAuthStateChanged
} from "https://www.gstatic.com/firebasejs/10.8.1/firebase-auth.js";
import {
  getFirestore, doc, setDoc, getDoc, getDocs, updateDoc, collection, arrayUnion
} from "https://www.gstatic.com/firebasejs/10.8.1/firebase-firestore.js";
import {
  getStorage, ref, uploadBytes, getDownloadURL
} from "https://www.gstatic.com/firebasejs/10.8.1/firebase-storage.js";

// Your actual Firebase config
const firebaseConfig = {
  apiKey: "AIzaSyAp_RTUf4zBJOpfvmu7KuU3NJX2OtnOsWs",
  authDomain: "dbtest-3c19f.firebaseapp.com",
  projectId: "dbtest-3c19f",
  storageBucket: "gs://dbtest-3c19f.firebasestorage.app",
  messagingSenderId: "569128437509",
  appId: "1:569128437509:web:abdc47d3b717fced9e996c",
  measurementId: "G-TQNQTC2970"
};

// Initialize Firebase services
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);
const storage = getStorage(app);


// SIGNUP
const signupForm = document.getElementById("signup-form");
if (signupForm) {
  signupForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    const name = document.getElementById("signup-name").value;
    const email = document.getElementById("signup-email").value;
    const password = document.getElementById("signup-password").value;

    if (password.length < 6) {
      alert("Password must be at least 6 characters long.");
      return;
    }

    try {
      const cred = await createUserWithEmailAndPassword(auth, email, password);
      await setDoc(doc(db, "users", cred.user.uid), {
        name, email, enrolledCourses: []
      });
      window.location.href = "dashboard.html";
    } catch (error) {
      alert("An error occurred: " + error.message);
    }
  });
}

// LOGIN
const loginForm = document.getElementById("login-form");
if (loginForm) {
  loginForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    const email = document.getElementById("login-email").value;
    const password = document.getElementById("login-password").value;

    try {
        await signInWithEmailAndPassword(auth, email, password);
        window.location.href = "dashboard.html";
    } catch (error) {
        if (error.code === "auth/user-not-found") {
            alert("This account does not exist");
        } else if (error.code === "auth/wrong-password") {
            alert("The password does not match the email");
        } else {
            alert("An error occurred: " + error.message);
        }
    }
  });
}

// DASHBOARD DISPLAY
const userName = document.getElementById("user-name");
const userEmail = document.getElementById("user-email");
if (userName && userEmail) {
  onAuthStateChanged(auth, async (user) => {
    if (!user) return (window.location.href = "login.html");

    const userDoc = await getDoc(doc(db, "users", user.uid));
    if (!userDoc.exists()) {
        console.warn("User document does not exist. Creating a new one.");
        await setDoc(doc(db, "users", user.uid), {
          name: user.displayName || "Default User",
          email: user.email || "unknown@email.com",
          enrolledCourses: [],
          privateNotes: []
        });
    } else {
        const data = userDoc.data();
        if (!data.name || !data.email) {
            console.warn("User data is incomplete. Updating with default values.");
            await updateDoc(doc(db, "users", user.uid), {
              name: data.name || "Default User",
              email: data.email || "unknown@email.com"
            });
        }
    }

    const data = userDoc.data();
    if (!data || !data.name) {
        console.error("User data is missing or incomplete.");
        return;
    }

    console.log("User data:", data);

    userName.textContent = data.name;

    document.addEventListener("DOMContentLoaded", () => {
      // Ensure the DOM is fully loaded before calling showTab
      showTab('myCourses');
    });

    const emailElement = document.getElementById("user-email");
    emailElement.style.display = "block";
    emailElement.querySelector("span").textContent = data.email;

    // Load Courses
    const allCourses = await getDocs(collection(db, "courses"));
    console.log("All courses fetched:", allCourses.docs.map(doc => doc.data()));
    const allList = document.getElementById("all-courses-list");
    allCourses.forEach((docSnap) => {
      const course = docSnap.data();
      if (!course.courseName.trim() || !course.description.trim()) {
        console.warn("Skipping invalid course:", course);
        return;
      }

      const li = document.createElement("li");

      const courseInfo = document.createElement("div");
      courseInfo.className = "course-info";
      courseInfo.innerHTML = `<strong>${course.courseName}</strong><span class="tagline">${getCourseTagline(course.courseName)}</span>`;

      const addButton = document.createElement("button");
      addButton.className = "circle-btn small-btn";
      addButton.textContent = "+";
      addButton.onclick = () => addCourseToMyCourses(docSnap.id);

      li.appendChild(courseInfo);
      li.appendChild(addButton);
      allList.appendChild(li);
    });

    // Remove the last 'Add to My Courses' button
    const extraButton = document.querySelector("#all-courses-list + button");
    if (extraButton) extraButton.remove();

    // Load User's Enrolled Courses
    const myCourses = data.enrolledCourses || [];
    const myList = document.getElementById("my-courses-list");
    myCourses.forEach(courseId => {
      const li = document.createElement("li");
      li.textContent = courseId;
      li.onclick = () => loadCourseDetails(courseId);
      myList.appendChild(li);
    });
  });
}

// LOGOUT
window.logout = async function () {
  await signOut(auth);
  window.location.href = "index.html"; // Redirect to the welcome page instead of the login page
};

// SAVE PRIVATE NOTES
window.savePrivateNotes = async function () {
  const user = auth.currentUser;
  const notes = document.getElementById("private-notes").value;
  await updateDoc(doc(db, "users", user.uid), {
    privateNotes: notes
  });
  alert("Notes saved!");
};

// FILE UPLOAD
window.uploadFile = async function () {
  const courseName = document.getElementById("selected-course-name").textContent;

  const isPrivateUpload = !courseName; // Check if the upload is for private notes

  const fileInputId = isPrivateUpload ? "note-upload-private" : "note-upload";
  const file = document.getElementById(fileInputId).files[0];
  console.log("Selected file:", file);
  if (!file) return alert("Choose a file!");

  if (isPrivateUpload) {
    const user = auth.currentUser;
    if (!user) return alert("You need to log in to upload private files.");

    const fileRef = ref(storage, `privateFiles/${user.uid}/${file.name}`);
    await uploadBytes(fileRef, file);
    const url = await getDownloadURL(fileRef);

    const privateFileRef = doc(collection(db, `users/${user.uid}/privateFiles`));
    await setDoc(privateFileRef, {
      fileUrl: url,
      filename: file.name,
      uploadedAt: new Date().toISOString()
    });

    alert("Private file uploaded successfully!");
    document.getElementById("note-upload").value = ""; // Reset the file input field after upload
    return;
  }

  const fileRef = ref(storage, `${courseName}/${file.name}`);
  await uploadBytes(fileRef, file);
  const url = await getDownloadURL(fileRef);

  const courseRef = doc(db, "courses", courseName);
  const fileData = {
    uploaderId: auth.currentUser.uid,
    fileUrl: url,
    filename: file.name,
    rating: 0,
    ratings: {}
  };
  await setDoc(doc(collection(courseRef, "uploadedFiles")), fileData);

  const uploadButton = document.getElementById("note-upload").nextElementSibling;
  if (uploadButton) {
    uploadButton.className = "circle-btn";
    uploadButton.textContent = "+";
  }

  alert("File uploaded!");
  document.getElementById("note-upload").value = ""; // Reset the file input field after upload
  loadCourseDetails(courseName);
};

// LOAD COURSE FILES
window.loadCourseDetails = async function (courseId) {
  document.getElementById("selected-course-name").textContent = courseId;
  document.getElementById("courseDetails").style.display = "block";

  const filesList = document.getElementById("course-files-list");
  filesList.innerHTML = "";

  const courseRef = doc(db, "courses", courseId);
  const files = await getDocs(collection(courseRef, "uploadedFiles"));
  files.forEach(fileSnap => {
    const file = fileSnap.data();
    const li = document.createElement("li");

    // File name
    const fileName = document.createElement("span");
    fileName.textContent = file.filename;
    fileName.style.cursor = "pointer";
    fileName.style.textDecoration = "underline";

    // Make the file name clickable to view the file
    fileName.onclick = () => {
      window.open(file.fileUrl, '_blank'); // Open the file in a new tab
    };

    // Rating container
    const ratingContainer = document.createElement("div");
    ratingContainer.style.marginTop = "10px";
    ratingContainer.style.display = "flex";
    ratingContainer.style.gap = "5px";

    // Create stars for rating
    for (let i = 1; i <= 5; i++) {
      const star = document.createElement("span");
      star.textContent = "★";
      star.style.cursor = "pointer";
      star.style.color = i <= (file.rating || 0) ? "gold" : "gray";
      star.onclick = () => submitRating(fileSnap.id, i);
      ratingContainer.appendChild(star);
    }

    // Average rating display
    const averageRating = document.createElement("span");
    averageRating.textContent = `Average Rating: ${(file.rating || 0).toFixed(1)}`;
    averageRating.style.marginLeft = "10px";

    li.appendChild(fileName);
    li.appendChild(ratingContainer);
    li.appendChild(averageRating);
    filesList.appendChild(li);
  });
};

// Function to submit a rating
window.submitRating = async function (fileId, rating) {
  const user = auth.currentUser;
  if (!user) return alert("You need to log in to rate files.");

  const courseName = document.getElementById("selected-course-name").textContent;
  const courseRef = doc(db, "courses", courseName);
  const fileRef = doc(collection(courseRef, "uploadedFiles"), fileId);

  const fileSnap = await getDoc(fileRef);
  const fileData = fileSnap.data();

  // Update ratings
  const ratings = fileData.ratings || {};
  ratings[user.uid] = parseInt(rating);

  // Calculate new average rating
  const totalRatings = Object.values(ratings);
  const averageRating = totalRatings.reduce((a, b) => a + b, 0) / totalRatings.length;

  await updateDoc(fileRef, {
    ratings,
    rating: averageRating
  });

  // Update the UI only if the element exists
  const ratingElement = document.getElementById(`file-rating-${fileId}`);
  if (ratingElement) {
    ratingElement.textContent = averageRating.toFixed(1);
  }
  alert("Rating submitted!");
};

// TABS
window.showTab = function (tabName) {
  document.querySelectorAll(".tab").forEach(tab => {
    tab.style.display = "none";
  });

  const tabElement = document.getElementById(tabName);
  if (!tabElement) {
    console.error(`Tab with id '${tabName}' not found.`);
    return; // Stop execution if the tab element is not found
  }

  tabElement.style.display = "block";

  // Show email only in the Profile tab
  const emailElement = document.getElementById("user-email");
  if (tabName === "profile") {
    emailElement.style.display = "block";
  } else {
    if (emailElement) {
      emailElement.style.display = "none";
    }
  }

  // Hide the course details section when switching tabs
  const courseDetailsElement = document.getElementById("courseDetails");
  if (courseDetailsElement) {
    courseDetailsElement.style.display = "none";
  }
};

// Add Course to My Courses
window.addCourseToMyCourses = async function (courseId) {
  const user = auth.currentUser;
  if (!user) return alert("You need to log in to add courses.");

  const userRef = doc(db, "users", user.uid);
  await updateDoc(userRef, {
    enrolledCourses: arrayUnion(courseId)
  });

  alert("Course added to My Courses!");
  location.reload(); // Refresh to update the My Courses tab
};

async function preloadCourses() {
  const courses = [
    {
      courseId: "Mathematics",
      courseName: "Mathematics",
      description: "Notes for high school and college-level mathematics."
    },
    {
      courseId: "ComputerScience",
      courseName: "Computer Science",
      description: "Programming, data structures, and computer theory notes."
    },
    {
      courseId: "Physics",
      courseName: "Physics",
      description: "Physics lecture notes and problem sets."
    },
    {
      courseId: "Chemistry",
      courseName: "Chemistry",
      description: "All things chemical—from atomic theory to organic."
    },
    {
      courseId: "Geography",
      courseName: "Geography",
      description: "Human and physical geography notes."
    }
  ];

  for (const course of courses) {
    if (!course.courseName.trim() || !course.description.trim()) {
      console.warn("Skipping invalid course:", course);
      continue;
    }
    await setDoc(doc(db, "courses", course.courseId), {
      courseName: course.courseName,
      description: course.description
    });
    console.log("✅ Added:", course.courseName);
  }
}

// Helper function to get course taglines and emojis
function getCourseTagline(courseName) {
  const taglines = {
    "Mathematics": "📐 Dive into numbers and equations!",
    "Computer Science": "💻 Code your way to the future!",
    "Physics": "🔭 Explore the laws of the universe!",
    "Chemistry": "⚗️ Unravel the mysteries of matter!",
    "Geography": "🌍 Discover the world around you!"
  };
  return taglines[courseName] || "📘 Learn something new!";
}

// Call it once after login
onAuthStateChanged(auth, (user) => {
  if (user) {
    preloadCourses(); // ← Add this line temporarily
  }
});

async function preloadTestUser() {
  const testUserId = "test-user-id"; // Replace with a valid UID for testing
  const testUserData = {
    name: "Test User",
    email: "testuser@example.com",
    enrolledCourses: []
  };

  try {
    await setDoc(doc(db, "users", testUserId), testUserData);
    console.log("Test user preloaded successfully.");
  } catch (error) {
    console.error("Error preloading test user:", error);
  }
}

// Call this function temporarily for testing
preloadTestUser();
