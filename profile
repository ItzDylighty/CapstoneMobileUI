import React, { useState, useCallback, useEffect } from "react";
import { View, Text, Image, StyleSheet, TouchableOpacity, ScrollView, Modal, TextInput, Platform, KeyboardAvoidingView, TouchableWithoutFeedback, Keyboard, Alert, RefreshControl, SafeAreaView } from "react-native";
import * as ImagePicker from "expo-image-picker";
import { useFocusEffect } from "expo-router";
import AsyncStorage from "@react-native-async-storage/async-storage";
import DateTimePicker from "@react-native-community/datetimepicker";
import Header from "../components/Header";
import Icon from "react-native-vector-icons/FontAwesome";
import { Ionicons } from '@expo/vector-icons';
import { supabase } from "../../supabase/supabaseClient";


const API_BASE = "http://192.168.254.114:3000/api";
const API_ORIGIN = API_BASE.replace(/\/api$/, "");


export default function ProfileScreen() {
  const [modalVisible, setModalVisible] = useState(false);
  const [firstName, setFirstName] = useState("");
  const [middleName, setMiddleName] = useState("");
  const [lastName, setLastName] = useState("");
  const [userNameField, setUserNameField] = useState("");
  const [username, setUsername] = useState("");
  const [sex, setSex] = useState("");
  const [birthday, setBirthday] = useState(new Date());
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [showSexDropdown, setShowSexDropdown] = useState(false);
  const [address, setAddress] = useState("");
  const [bio, setBio] = useState("");
  const [about, setAbout] = useState("");
  const [image, setImage] = useState(null);
  const [backgroundImage, setBackgroundImage] = useState(null);
  const [selectedArt, setSelectedArt] = useState(null);
  const [tempImage, setTempImage] = useState(null);
  const [tempBackgroundImage, setTempBackgroundImage] = useState(null);
  const [tempFirstName, setTempFirstName] = useState("");
  const [tempMiddleName, setTempMiddleName] = useState("");
  const [tempLastName, setTempLastName] = useState("");
  const [tempUserNameField, setTempUserNameField] = useState("");
  const [tempSex, setTempSex] = useState("");
  const [tempBirthday, setTempBirthday] = useState(new Date());
  const [tempAddress, setTempAddress] = useState("");
  const [tempBio, setTempBio] = useState("");
  const [tempAbout, setTempAbout] = useState("");
  const [accessToken, setAccessToken] = useState(null);
  const [refreshToken, setRefreshToken] = useState(null);
  const [galleryImages, setGalleryImages] = useState([]);
  const [role, setRole] = useState(null);
  // Artwork upload modal state
  const [artModalVisible, setArtModalVisible] = useState(false);
  const [artImage, setArtImage] = useState(null); // { uri }
  const [artTitle, setArtTitle] = useState("");
  const [artDescription, setArtDescription] = useState("");
  const [artMedium, setArtMedium] = useState("");
  const [artUploading, setArtUploading] = useState(false);
  // Artwork interactions (likes/comments)
  const [artComments, setArtComments] = useState([]);
  const [artLikesCount, setArtLikesCount] = useState(0);
  const [artUserLiked, setArtUserLiked] = useState(false);
  const [artNewComment, setArtNewComment] = useState("");
  const [refreshing, setRefreshing] = useState(false);

  // Apply as Artist modal state
  const [applyModalVisible, setApplyModalVisible] = useState(false);
  const [appFirstName, setAppFirstName] = useState("");
  const [appMiddleInitial, setAppMiddleInitial] = useState("");
  const [appLastName, setAppLastName] = useState("");
  const [appPhone, setAppPhone] = useState("");
  const [appAge, setAppAge] = useState("");
  const [appSex, setAppSex] = useState("");
  const [appBirthdate, setAppBirthdate] = useState(new Date());
  const [appShowSexDropdown, setAppShowSexDropdown] = useState(false);
  const [appShowDatePicker, setAppShowDatePicker] = useState(false);
  const [appAddress, setAppAddress] = useState("");
  const [appValidIdImage, setAppValidIdImage] = useState(null); // { uri }
  const [appSelfieImage, setAppSelfieImage] = useState(null);   // { uri }
  const [appSubmitting, setAppSubmitting] = useState(false);
  const [hasPendingRequest, setHasPendingRequest] = useState(false);


  // Function to upload artwork image to the backend and refresh gallery
  const uploadArtwork = async (imageUri, meta = {}) => {
    try {
      // Ensure we have tokens; if not, try to fetch current session
      let at = accessToken;
      let rt = refreshToken;
      if (!at || !rt) {
        const { data } = await supabase.auth.getSession();
        at = data?.session?.access_token || at;
        rt = data?.session?.refresh_token || rt;
        if (at) setAccessToken(at);
        if (rt) setRefreshToken(rt);
      }
      const fd = new FormData();
      // Backend expects single file under field name 'image'
      fd.append("image", {
        uri: imageUri,
        name: "artwork.jpg",
        type: "image/jpeg",
      });
      // Optional metadata supported by backend: title, description, medium
      if (meta.title != null) fd.append("title", String(meta.title));
      if (meta.description != null) fd.append("description", String(meta.description));
      if (meta.medium != null) fd.append("medium", String(meta.medium));


      const res = await fetch(`${API_BASE}/profile/uploadArt`, {
        method: "POST",
        headers: {
          // Include auth cookies so backend can read req.user
          Cookie: `access_token=${at}; refresh_token=${rt}`,
        },
        body: fd,
      });


      if (!res.ok) {
        let msg = res.statusText;
        try {
          const bodyText = await res.text();
          try {
            const bodyJson = bodyText ? JSON.parse(bodyText) : null;
            msg = bodyJson?.error || bodyJson?.message || bodyText || msg;
          } catch (_) {
            msg = bodyText || msg;
          }
        } catch (_) {}
        console.log("[uploadArtwork] failed:", res.status, msg);
        throw new Error(`Upload failed (${res.status}): ${msg}`);
      }


      const data = await res.json();
      console.log("Upload response:", data);
      // Refresh gallery after successful upload
      await fetchGallery(at, rt);
    } catch (err) {
      console.error("Error uploading artwork:", err);
      alert("Failed to upload artwork");
    }
  };


  // Load reactions and comments when an artwork is opened
  useEffect(() => {
    const load = async () => {
      if (!selectedArt?.id) return;
      await Promise.all([
        fetchArtReacts(selectedArt.id),
        fetchArtComments(selectedArt.id),
      ]);
    };
    load();
  }, [selectedArt]);


  const fetchArtReacts = async (artId) => {
    try {
      let at = accessToken, rt = refreshToken;
      if (!at || !rt) {
        const { data } = await supabase.auth.getSession();
        at = data?.session?.access_token || at;
        rt = data?.session?.refresh_token || rt;
      }
      const res = await fetch(`${API_BASE}/profile/getReact?artId=${artId}`, {
        method: "GET",
        headers: { Cookie: `access_token=${at}; refresh_token=${rt}` },
      });
      if (!res.ok) return;
      const bodyText = await res.text();
      let data = null; try { data = bodyText ? JSON.parse(bodyText) : null; } catch { data = null; }
      const reactions = data?.reactions || [];
      setArtLikesCount(reactions.length || 0);
      // Determine if current user liked
      const session = await supabase.auth.getSession();
      const uid = session?.data?.session?.user?.id;
      setArtUserLiked(!!reactions.find(r => r.userId === uid));
    } catch {}
  };


  const fetchArtComments = async (artId) => {
    try {
      let at = accessToken, rt = refreshToken;
      if (!at || !rt) {
        const { data } = await supabase.auth.getSession();
        at = data?.session?.access_token || at;
        rt = data?.session?.refresh_token || rt;
      }
      const res = await fetch(`${API_BASE}/profile/getComments?artId=${artId}`, {
        method: "GET",
        headers: { Cookie: `access_token=${at}; refresh_token=${rt}` },
      });
      if (!res.ok) return;
      const json = await res.json();
      setArtComments(json?.comments || []);
    } catch {}
  };


  const handleToggleArtLike = async () => {
    if (!selectedArt?.id) return;
    const prevLiked = artUserLiked;
    const prevCount = artLikesCount;
    setArtUserLiked(!prevLiked);
    setArtLikesCount(prevLiked ? Math.max(0, prevCount - 1) : prevCount + 1);
    try {
      let at = accessToken, rt = refreshToken;
      if (!at || !rt) {
        const { data } = await supabase.auth.getSession();
        at = data?.session?.access_token || at;
        rt = data?.session?.refresh_token || rt;
      }
      const res = await fetch(`${API_BASE}/profile/createReact`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Cookie: `access_token=${at}; refresh_token=${rt}`,
        },
        body: JSON.stringify({ artId: selectedArt.id }),
      });
      if (!res.ok) throw new Error('react failed');
      await fetchArtReacts(selectedArt.id);
    } catch {
      // revert on failure
      setArtUserLiked(prevLiked);
      setArtLikesCount(prevCount);
    }
  };


  const postArtComment = async () => {
    if (!selectedArt?.id || !artNewComment.trim()) return;
    const text = artNewComment.trim();
    setArtNewComment("");
    try {
      let at = accessToken, rt = refreshToken;
      if (!at || !rt) {
        const { data } = await supabase.auth.getSession();
        at = data?.session?.access_token || at;
        rt = data?.session?.refresh_token || rt;
      }
      const res = await fetch(`${API_BASE}/profile/createComment`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Cookie: `access_token=${at}; refresh_token=${rt}`,
        },
        body: JSON.stringify({ artId: selectedArt.id, text }),
      });
      if (!res.ok) throw new Error('comment failed');
      await fetchArtComments(selectedArt.id);
    } catch {}
  };
  

  const formattedDate = birthday
    ? birthday.toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })
    : "";
  const formattedTempDate = tempBirthday
    ? tempBirthday.toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })
    : "";


  const handleAddImage = async () => {
    // Only artists/admin can upload
    const r = String(role || '').toLowerCase();
    if (!(r === 'artist' || r === 'admin')) {
      console.log('[profile.js] Upload blocked due to role:', role);
      Alert.alert('Not allowed', 'Only artists can upload artworks.');
      return;
    }
    // Open modal to collect artwork metadata and image
    setArtImage(null);
    setArtTitle("");
    setArtDescription("");
    setArtMedium("");
    setArtModalVisible(true);
  };


  const pickArtworkImage = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [1, 1],
      quality: 1,
    });
    if (!result.canceled) {
      setArtImage({ uri: result.assets[0].uri });
    }
  };


  const submitArtwork = async () => {
    try {
      if (!artTitle.trim()) {
        Alert.alert('Error', 'Please enter a title');
        return;
      }
      if (!artImage?.uri) {
        Alert.alert('Error', 'Please select an artwork image');
        return;
      }
      setArtUploading(true);
      await uploadArtwork(artImage.uri, {
        title: artTitle,
        description: artDescription,
        medium: artMedium,
      });
      Alert.alert('Success', 'Artwork uploaded successfully!');
      setArtModalVisible(false);
      setArtImage(null);
      setArtTitle('');
      setArtDescription('');
      setArtMedium('');
    } catch (e) {
      // uploadArtwork already alerts on failure
    } finally {
      setArtUploading(false);
    }
  };


  const handleApplyAsArtist = () => {
    console.log('[profile.js] Apply as Artist clicked. Current role =', role);
    // Prefill from existing profile data if available
    setAppFirstName(firstName || "");
    setAppMiddleInitial((middleName || "").slice(0,1).toUpperCase());
    setAppLastName(lastName || "");
    setAppSex(sex || "");
    setAppBirthdate(birthday || new Date());
    setAppAddress(address || "");
    setAppPhone("");
    setAppAge("");
    setAppValidIdImage(null);
    setAppSelfieImage(null);
    setApplyModalVisible(true);
  };

  const pickValidIdImage = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [4, 3],
      quality: 1,
    });
    if (!result.canceled) {
      setAppValidIdImage({ uri: result.assets[0].uri });
    }
  };

  const pickSelfieImage = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [1, 1],
      quality: 1,
    });
    if (!result.canceled) {
      setAppSelfieImage({ uri: result.assets[0].uri });
    }
  };

  const onChangeAppDate = (event, selectedDate) => {
    if (selectedDate) setAppBirthdate(selectedDate);
    if (Platform.OS === 'android') setAppShowDatePicker(false);
  };

  const submitArtistApplication = async () => {
    try {
      if (!appFirstName || !appLastName || !appPhone || !appAge || !appSex || !appBirthdate || !appAddress || !appValidIdImage || !appSelfieImage) {
        Alert.alert('Incomplete', 'Please fill in all fields and attach both images.');
        return;
      }
      setAppSubmitting(true);

      // Ensure tokens
      let at = accessToken, rt = refreshToken;
      if (!at || !rt) {
        const { data } = await supabase.auth.getSession();
        at = data?.session?.access_token || at;
        rt = data?.session?.refresh_token || rt;
      }

      // Build multipart form data to mirror the web submission to admin
      const fd = new FormData();
      fd.append('requestType', 'artist_verification');
      fd.append('firstName', String(appFirstName));
      fd.append('midInit', String(appMiddleInitial || ''));
      fd.append('lastName', String(appLastName));
      fd.append('phone', String(appPhone));
      fd.append('age', String(appAge));
      fd.append('sex', String(appSex));
      fd.append('birthdate', new Date(appBirthdate).toISOString());
      fd.append('address', String(appAddress));
      // Optional fields to match web (empty if not used in RN UI)
      fd.append('portfolio', '');
      fd.append('bio', '');
      // Consent required by web flow; RN UI has no toggle, so set true to match web behavior
      fd.append('consent', 'true');
      // Files must be under field names 'file' and 'file2' as in the web app
      fd.append('file', { uri: appValidIdImage.uri, name: 'valid_id.jpg', type: 'image/jpeg' });
      fd.append('file2', { uri: appSelfieImage.uri, name: 'selfie.jpg', type: 'image/jpeg' });

      const endpoint = `${API_BASE}/request/registerAsArtist`;
      console.log('[profile.js] Submitting artist application to (admin/web route):', endpoint);
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { Cookie: `access_token=${at}; refresh_token=${rt}` },
        body: fd,
      });
      const bodyText = await res.text();
      console.log('[profile.js] Application response:', res.status, bodyText);
      if (!res.ok) throw new Error(bodyText || 'Application failed');

      // Trigger existing refresh logic to update profile/gallery state
      try { await onRefresh(); } catch (_) {}
      Alert.alert('Submitted', 'Your application has been submitted.');
      setApplyModalVisible(false);
    } catch (e) {
      console.error('[profile.js] submitArtistApplication error:', e?.message || e);
      Alert.alert('Failed', e?.message || 'Could not submit application');
    } finally {
      setAppSubmitting(false);
    }
  };

  // Fetch user role (same concept as in home.js), with verbose logs
  const fetchRole = async (at, rt) => {
    try {
      const res = await fetch(`${API_BASE}/users/role`, {
        method: "GET",
        credentials: "include",
        headers: {
          Cookie: `access_token=${at}; refresh_token=${rt}`,
        },
      });
      if (!res.ok) throw new Error(`Failed to fetch role: ${res.status} ${res.statusText}`);

      const bodyText = await res.text();
      console.log("[profile.js] Fetched role raw:", bodyText);
      let data = null;
      try {
        data = bodyText ? JSON.parse(bodyText) : null;
      } catch (_) {
        data = bodyText; // plain string role fallback
      }

      const resolvedRole = typeof data === "string"
        ? data
        : (data?.role || data?.user?.role || data?.data?.role || data?.profile?.role || null);
      setRole(resolvedRole);
      console.log("[profile.js] Resolved role:", resolvedRole ?? "(null/unknown)");
      return resolvedRole;
    } catch (error) {
      console.error("[profile.js] Error fetching role:", error?.message || error);
      setRole(null);
      return null;
    }
  };

  // Check if user has a pending artist verification request
  const checkPendingRequest = async (at, rt) => {
    try {
      const res = await fetch(`${API_BASE}/request/getRequest`, {
        method: "GET",
        credentials: "include",
        headers: {
          Cookie: `access_token=${at}; refresh_token=${rt}`,
        },
      });
      if (!res.ok) {
        setHasPendingRequest(false);
        return false;
      }
      const data = await res.json();
      
      // Check if there's a pending artist_verification request
      if (data?.requests && Array.isArray(data.requests)) {
        const pendingArtistRequest = data.requests.find(
          req => req.requestType === 'artist_verification' && req.status === 'pending'
        );
        const hasPending = !!pendingArtistRequest;
        setHasPendingRequest(hasPending);
        console.log("[profile.js] Pending artist request:", hasPending);
        return hasPending;
      }
      setHasPendingRequest(false);
      return false;
    } catch (error) {
      console.error("[profile.js] Error checking pending request:", error?.message || error);
      setHasPendingRequest(false);
      return false;
    }
  };


  useEffect(() => {
    const init = async () => {
      try {
        const { data } = await supabase.auth.getSession();
        const at = data?.session?.access_token || null;
        const rt = data?.session?.refresh_token || null;
        setAccessToken(at);
        setRefreshToken(rt);


        if (at && rt) {
          const r = await fetchRole(at, rt);
          await fetchProfile(at, rt);
          await checkPendingRequest(at, rt);
          if (String(r || '').toLowerCase() === 'artist' || String(r || '').toLowerCase() === 'admin') {
            await fetchGallery(at, rt);
          } else {
            console.log('[profile.js] Role not permitted to view gallery. Skipping fetchGallery. role =', r);
            setGalleryImages([]);
          }
        } else {
          await fetchSupabaseProfile();
        }
      } catch (e) {
        console.warn("Init session failed:", e?.message || e);
      }
    };
    init();
  }, []);

  // Debug: log role changes to verify UI conditions
  useEffect(() => {
    console.log('[profile.js] role state now:', role);
  }, [role]);

  
  const fetchSupabaseProfile = async () => {
    try {
      const { data: { user }, error } = await supabase.auth.getUser();
      if (error) throw error;
      if (!user) return;
      const { data: profile, error: profileError } = await supabase
        .from("profiles")
        .select("*")
        .eq("id", user.id)
        .single();


      if (profileError) throw profileError;


      setFirstName(profile.first_name || "");
      setMiddleName(profile.middle_name || "");
      setLastName(profile.last_name || "");
      setUsername(profile.username || "");
      setUserNameField(profile.username || "");
      setSex(profile.sex || "");
      setAddress(profile.address || "");
      setBio(profile.bio || "");
      setAbout(profile.about || "");


      if (profile.birthday) {
        const parsed = new Date(profile.birthday);
        setBirthday(parsed);
        await AsyncStorage.setItem("userBirthday", parsed.toISOString());
      }
    } catch (err) {
      console.warn("Supabase profile fetch failed:", err.message);
    }
  };


  const getInitials = () => {
    const parts = [firstName, middleName, lastName].filter(Boolean);
    let base = parts.join(" ");
    if (!base && username) base = username;
    if (!base) return "";
    const tokens = base.trim().split(/\s+/);
    return tokens
      .slice(0, 2)
      .map((t) => t[0]?.toUpperCase())
      .join("");
  };


  const fetchProfile = async (at = accessToken, rt = refreshToken) => {
    try {
      const res = await fetch(`${API_BASE}/profile/getProfile`, {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          Cookie: `access_token=${at}; refresh_token=${rt}`,
        },
      });
      if (!res.ok) throw new Error(`Failed to fetch profile (${res.status})`);


      const data = await res.json();
      const p = data?.profile ?? data;


      setFirstName(p.firstName || "");
      setMiddleName(p.middleName || "");
      setLastName(p.lastName || "");
      setUserNameField(p.username || "");
      setUsername(p.username || "");
      setSex(p.sex || "");
      setAddress(p.address || "");
      setBio(p.bio || "");
      setAbout(p.about || "");


      const fetchedBday = p.birthday || p.birthdate;
      if (fetchedBday) {
        const parsedDate = new Date(fetchedBday);
        setBirthday(parsedDate);
        await AsyncStorage.setItem("userBirthday", parsedDate.toISOString());
      }


      const resolveUrl = (u) => {
        if (!u) return null;
        return u.startsWith("http") ? u : `${API_ORIGIN}${u}`;
      };
      const avatarUrl = resolveUrl(p.profilePicture);
      const coverUrl = resolveUrl(p.coverPicture);
      setImage(avatarUrl ? { uri: avatarUrl } : null);
      setBackgroundImage(coverUrl ? { uri: coverUrl } : null);
    } catch (err) {
      console.warn("Profile fetch failed:", err.message);
      await fetchSupabaseProfile();
    }
  };


  // Fetch user's artworks and populate galleryImages
  const fetchGallery = async (at = accessToken, rt = refreshToken) => {
    try {
      const res = await fetch(`${API_BASE}/profile/getArts`, {
        method: "GET",
        headers: {
          Cookie: `access_token=${at}; refresh_token=${rt}`,
        },
      });
      if (!res.ok) throw new Error(`Failed to fetch gallery (${res.status})`);
      const data = await res.json();
      const list = Array.isArray(data) ? data : (data?.arts || data || []);
      const items = list.map((a) => {
        // Image is stored as JSONB array, extract first URL
        let imageUrl = null;
        if (Array.isArray(a?.image) && a.image.length > 0) {
          imageUrl = a.image[0];
        } else if (typeof a?.image === 'string') {
          imageUrl = a.image;
        }
        
        // Make URL absolute if needed
        const abs = imageUrl ? (imageUrl.startsWith("http") ? imageUrl : `${API_ORIGIN}${imageUrl}`) : null;
        
        return {
          id: a?.artId || a?.id || null,
          image: abs,
          title: a?.title || null,
          description: a?.description || null,
          medium: a?.medium || null,
          timestamp: a?.timestamp || a?.datePosted || null,
        };
      }).filter(x => !!x.image);
      setGalleryImages(items);
    } catch (e) {
      console.warn("Gallery fetch failed:", e?.message || e);
    }
  };


  useFocusEffect(
    useCallback(() => {
      fetchProfile();
      const r = String(role || '').toLowerCase();
      if (accessToken && refreshToken && (r === 'artist' || r === 'admin')) {
        fetchGallery(accessToken, refreshToken);
      } else if (accessToken && refreshToken) {
        console.log('[profile.js] Focus effect: role not permitted to view gallery. role =', role);
        setGalleryImages([]);
      }
    }, [role, accessToken, refreshToken])
  );

  // Pull to refresh handler
  const onRefresh = async () => {
    setRefreshing(true);
    try {
      // Fetch role first to get the latest role from backend
      const updatedRole = await fetchRole(accessToken, refreshToken);
      const r = String(updatedRole || '').toLowerCase();
      
      if (r === 'artist' || r === 'admin') {
        await Promise.all([
          fetchProfile(accessToken, refreshToken),
          fetchGallery(accessToken, refreshToken),
          checkPendingRequest(accessToken, refreshToken)
        ]);
      } else {
        await Promise.all([
          fetchProfile(accessToken, refreshToken),
          checkPendingRequest(accessToken, refreshToken)
        ]);
      }
    } catch (err) {
      console.error('Refresh error:', err);
    } finally {
      setRefreshing(false);
    }
  };


  const pickImage = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [1, 1],
      quality: 1,
    });
    if (!result.canceled) {
      const uri = result.assets[0].uri;
      const imgObj = { uri };
      setTempImage(imgObj);
      setImage(imgObj);
    }
  };


  const pickBackgroundImage = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [16, 9],
      quality: 1,
    });
    if (!result.canceled) {
      const uri = result.assets[0].uri;
      const bgObj = { uri };
      setTempBackgroundImage(bgObj);
      setBackgroundImage(bgObj);
    }
  };


  const handleSave = async () => {
    try {
      const formData = new FormData();
      if (tempImage) {
        const filename = tempImage.uri.split("/").pop();
        const match = /\.(\w+)$/.exec(filename);
        const type = match ? `image/${match[1]}` : "image";
        formData.append("avatar", { uri: tempImage.uri, name: filename, type });
      }
      if (tempBackgroundImage) {
        const filename = tempBackgroundImage.uri.split("/").pop();
        const match = /\.(\w+)$/.exec(filename);
        const type = match ? `image/${match[1]}` : "image";
        formData.append("cover", { uri: tempBackgroundImage.uri, name: filename, type });
      }


      formData.append("firstName", String(tempFirstName ?? ""));
      formData.append("middleName", String(tempMiddleName ?? ""));
      formData.append("lastName", String(tempLastName ?? ""));
      formData.append("username", String(tempUserNameField || username || ""));
      formData.append("sex", String(tempSex ?? ""));
      const birthdayISO = tempBirthday ? new Date(tempBirthday).toISOString() : "";
      formData.append("birthday", birthdayISO);
      formData.append("birthdate", birthdayISO);
      formData.append("address", String(tempAddress ?? ""));
      formData.append("bio", String(tempBio ?? ""));
      formData.append("about", String(tempAbout ?? ""));


      if (tempBirthday) {
        await AsyncStorage.setItem("userBirthday", new Date(tempBirthday).toISOString());
      }


      const res = await fetch(`${API_BASE}/profile/updateProfile`, {
        method: "POST",
        headers: {
          Cookie: `access_token=${accessToken}; refresh_token=${refreshToken}`,
        },
        body: formData,
      });


      if (!res.ok) {
        let errorMsg = "Failed to update profile";
        try {
          const errorData = await res.json();
          errorMsg = errorData?.message || errorData?.error || errorMsg;
        } catch {}
        throw new Error(errorMsg);
      }


      setModalVisible(false);
      setTempImage(null);
      setTempBackgroundImage(null);
      await fetchProfile();


      Alert.alert("Success", "Profile updated successfully!");
    } catch (err) {
      console.error("Profile update error:", err);
      Alert.alert("Update Failed", err?.message || "Failed to save profile information");
    }
  };


  const onChangeTempDate = (event, selectedDate) => {
    if (selectedDate) setTempBirthday(selectedDate);
    if (Platform.OS === "android") setShowDatePicker(false);
  };


  return (
    <SafeAreaView style={styles.container}>
      <Header title="Profile" showSearch={false} />
      <ScrollView 
        style={styles.scrollContent}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={onRefresh}
            colors={['#000']} // Android
            tintColor="#000" // iOS
          />
        }
      >


      {/* Profile Section */}
      <View style={styles.profileSection}>
        {backgroundImage ? (
          <Image source={backgroundImage} style={styles.backgroundImage} />
        ) : (
          <Image source={require("../../assets/pic1.jpg")} style={styles.backgroundImage} />
        )}


      {/* Apply as Artist Modal */}
      <Modal
        visible={applyModalVisible}
        animationType="slide"
        transparent
        onRequestClose={() => setApplyModalVisible(false)}
      >
        <KeyboardAvoidingView 
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={{ flex: 1 }}
        >
          <View style={styles.uploadModalOverlay}>
            <View style={styles.uploadModalContent}>
              <View style={styles.uploadModalHeader}>
                <Text style={styles.uploadModalTitle}>Apply as Artist</Text>
                <TouchableOpacity onPress={() => setApplyModalVisible(false)}>
                  <Ionicons name="close" size={24} color="#333" />
                </TouchableOpacity>
              </View>

              <ScrollView style={styles.uploadModalBody} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">

                <Text style={styles.uploadInputLabel}>First Name *</Text>
                <TextInput style={styles.uploadInput} placeholder="First Name" value={appFirstName} onChangeText={setAppFirstName} />
                
                <Text style={styles.uploadInputLabel}>Middle Initial</Text>
                <TextInput style={styles.uploadInput} placeholder="Middle Initial" value={appMiddleInitial} onChangeText={setAppMiddleInitial} maxLength={1} />
                
                <Text style={styles.uploadInputLabel}>Last Name *</Text>
                <TextInput style={styles.uploadInput} placeholder="Last Name" value={appLastName} onChangeText={setAppLastName} />
                
                <Text style={styles.uploadInputLabel}>Phone Number *</Text>
                <TextInput style={styles.uploadInput} placeholder="Phone Number" keyboardType="phone-pad" value={appPhone} onChangeText={setAppPhone} />
                
                <Text style={styles.uploadInputLabel}>Age *</Text>
                <TextInput style={styles.uploadInput} placeholder="Age" keyboardType="numeric" value={appAge} onChangeText={setAppAge} />

                <Text style={styles.uploadInputLabel}>Sex *</Text>
                <TouchableOpacity style={styles.uploadInput} onPress={() => setAppShowSexDropdown(!appShowSexDropdown)}>
                  <Text style={{ color: appSex ? '#000' : '#999' }}>{appSex || 'Select Sex'}</Text>
                  <Ionicons name={appShowSexDropdown ? 'chevron-up' : 'chevron-down'} size={20} color="#555" style={{ position: 'absolute', right: 12, top: 12 }} />
                </TouchableOpacity>
                {appShowSexDropdown && (
                  <View style={styles.categoryDropdown}>
                    {['Male', 'Female', 'PreferNotToSay'].map(item => (
                      <TouchableOpacity key={item} style={styles.categoryItem} onPress={() => { setAppSex(item); setAppShowSexDropdown(false); }}>
                        <Text style={styles.categoryItemText}>{item}</Text>
                      </TouchableOpacity>
                    ))}
                  </View>
                )}

                <Text style={styles.uploadInputLabel}>Birthdate *</Text>
                <TouchableOpacity style={styles.uploadInput} onPress={() => setAppShowDatePicker(true)}>
                  <Text style={{ color: appBirthdate ? '#000' : '#999' }}>
                    {appBirthdate ? appBirthdate.toLocaleDateString('en-US') : 'Select your birthdate'}
                  </Text>
                </TouchableOpacity>
                {appShowDatePicker && (
                  <DateTimePicker value={appBirthdate} mode="date" display="default" onChange={onChangeAppDate} />
                )}

                <Text style={styles.uploadInputLabel}>Address *</Text>
                <TextInput style={styles.uploadInput} placeholder="Address" value={appAddress} onChangeText={setAppAddress} />

                <Text style={styles.uploadInputLabel}>Valid ID *</Text>
                <TouchableOpacity onPress={pickValidIdImage} style={styles.uploadImagePicker}>
                  {appValidIdImage ? (
                    <Image source={appValidIdImage} style={styles.uploadPickedImage} />
                  ) : (
                    <View style={styles.uploadImagePlaceholder}>
                      <Ionicons name="card-outline" size={48} color="#A68C7B" />
                      <Text style={styles.uploadImageText}>Tap to upload Valid ID</Text>
                    </View>
                  )}
                </TouchableOpacity>

                <Text style={styles.uploadInputLabel}>Selfie *</Text>
                <TouchableOpacity onPress={pickSelfieImage} style={styles.uploadImagePicker}>
                  {appSelfieImage ? (
                    <Image source={appSelfieImage} style={styles.uploadPickedImage} />
                  ) : (
                    <View style={styles.uploadImagePlaceholder}>
                      <Ionicons name="person-outline" size={48} color="#A68C7B" />
                      <Text style={styles.uploadImageText}>Tap to upload Selfie</Text>
                    </View>
                  )}
                </TouchableOpacity>

                <TouchableOpacity
                  style={[styles.uploadButton, appSubmitting && styles.uploadButtonDisabled]}
                  onPress={submitArtistApplication}
                  disabled={appSubmitting}
                >
                  <Text style={styles.uploadButtonText}>
                    {appSubmitting ? 'Submitting...' : 'Submit Application'}
                  </Text>
                </TouchableOpacity>
              </ScrollView>
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>
        <View style={styles.avatarContainer}>
          {image ? (
            <Image source={image} style={styles.avatar} />
          ) : (
            <View style={[styles.avatar, styles.placeholderCircle, { backgroundColor: "#dfe3e8" }]}>
              {getInitials() ? (
                <Text style={{ fontSize: 32, fontWeight: "bold", color: "#555" }}>
                  {getInitials()}
                </Text>
              ) : (
                <Icon name="user" size={50} color="#999" />
              )}
            </View>
          )}
        </View>


        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', marginTop: -30 }}>
          <Text style={[styles.name, { marginTop: 0 }]}>{username || "Username"}</Text>
          {(String(role || '').toLowerCase() === 'artist' || String(role || '').toLowerCase() === 'admin') && (
            <Ionicons name="checkmark-circle" size={20} color="#1DA1F2" style={{ marginLeft: 6 }} />
          )}
        </View>
        <View style={styles.infoContainer}>
          <Text style={styles.detail}><Text style={styles.detailLabel}>Name:</Text> {[firstName, middleName, lastName].filter(Boolean).join(' ') || "Not set"}</Text>
          <Text style={styles.detail}><Text style={styles.detailLabel}>Gender:</Text> {sex || "Not set"}</Text>
          <Text style={styles.detail}><Text style={styles.detailLabel}>Birthdate:</Text> {formattedDate || "Not set"}</Text>
          <Text style={styles.detail}><Text style={styles.detailLabel}>Address:</Text> {address}</Text>
          <Text style={styles.detail}><Text style={styles.detailLabel}>Bio:</Text> {bio}</Text>
        </View>

        <View style={styles.infoContainer}>
          <Text style={styles.detail}><Text style={styles.detailLabel}>About:</Text> {about}</Text>
        </View>


        <View style={styles.buttonContainer}>
          <View style={styles.buttonRow}>
            <TouchableOpacity
              style={styles.button}
              onPress={() => {
                setTempImage(image);
                setTempBackgroundImage(backgroundImage);
                setTempFirstName(firstName);
                setTempMiddleName(middleName);
                setTempLastName(lastName);
                setTempUserNameField(userNameField || username);
                setTempSex(sex);
                setTempBirthday(birthday || new Date());
                setTempAddress(address);
                setTempBio(bio);
                setTempAbout(about);
                setModalVisible(true);
              }}
            >
              <Text style={styles.buttonText}>Edit Profile</Text>
            </TouchableOpacity>
            {(() => {
              const r = String(role ?? '').trim().toLowerCase();
              // Hide button only if: user is artist/admin
              const isArtistOrAdmin = r === 'artist' || r === 'admin';
              const shouldShow = !isArtistOrAdmin;
              return shouldShow;
            })() && (
              <TouchableOpacity 
                style={[styles.button, hasPendingRequest && { opacity: 0.5 }]} 
                onPress={handleApplyAsArtist}
                disabled={hasPendingRequest}
              >
                <Text style={styles.buttonText}>Apply as Artist</Text>
              </TouchableOpacity>
            )}
          </View>
          {(() => {
            const r = String(role ?? '').trim().toLowerCase();
            const isArtistOrAdmin = r === 'artist' || r === 'admin';
            // Only show pending button if user has pending request AND is not already artist/admin
            return hasPendingRequest && !isArtistOrAdmin;
          })() && (
            <TouchableOpacity style={[styles.button, styles.pendingButton, styles.fullWidthButton]} disabled>
              <Text style={styles.buttonText}>✓ Verification Pending</Text>
            </TouchableOpacity>
          )}
        </View>
      </View>


      {/* Artwork Galleries - visible only to artist/admin */}
      {(String(role || '').toLowerCase() === 'artist' || String(role || '').toLowerCase() === 'admin') && (
        <>
          <Text style={styles.sectionTitle}>My Artwork</Text>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            style={styles.galleryRow}
            decelerationRate={Platform.OS === 'ios' ? 'fast' : 0.98}
            scrollEventThrottle={16}
          >
            {galleryImages.map((art, index) => (
              <TouchableOpacity key={index} onPress={() => setSelectedArt(art)}>
                <Image source={{ uri: art.image }} style={styles.galleryItem} />
              </TouchableOpacity>
            ))}
            <TouchableOpacity style={styles.addImageBox} onPress={handleAddImage}>
              <Text style={styles.addImageText}>+</Text>
            </TouchableOpacity>
          </ScrollView>
        </>
      )}


      {/* Artwork Details Modal */}
      <Modal visible={selectedArt !== null} transparent animationType="fade" onRequestClose={() => setSelectedArt(null)}>
        <View style={styles.fullScreenContainer}>
          <View style={{ width: '90%', maxHeight: '85%', backgroundColor: '#fff', borderRadius: 12, overflow: 'hidden' }}>
            {/* Explicit close button */}
            <TouchableOpacity onPress={() => setSelectedArt(null)} style={styles.modalCloseButton}>
              <Ionicons name="close" size={24} color="white" />
            </TouchableOpacity>
            {/* Changed this block to ScrollView for vertical scroll */}
            <ScrollView
              contentContainerStyle={{ paddingBottom: 16 }}
              decelerationRate={Platform.OS === 'ios' ? 'fast' : 0.98}
              scrollEventThrottle={16}
              showsVerticalScrollIndicator
            >
              {selectedArt?.image && (
               <Image source={{ uri: selectedArt.image }} style={styles.artModalImage} />   //BINAGO KO RON
              )}
              <View style={{ padding: 12 }}>
                
              <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 6 }}>
                  {!!selectedArt?.title && (
                    <Text style={{ fontSize: 18, fontWeight: 'bold', flex: 1 }}>{selectedArt.title}</Text>
                  )}
                  <TouchableOpacity onPress={handleToggleArtLike} style={{ flexDirection: 'row', alignItems: 'center' }}>
                    <Icon name={artUserLiked ? 'heart' : 'heart-o'} size={22} color={artUserLiked ? 'red' : '#555'} />
                    <Text style={{ marginLeft: 6 }}>{artLikesCount}</Text>
                  </TouchableOpacity>
                </View>

                {!!selectedArt?.medium && (<Text style={{ fontSize: 14, color: '#555', marginBottom: 8 }}>Medium: {selectedArt.medium}</Text>)}
                {!!selectedArt?.description && (<Text style={{ fontSize: 14, color: '#222' }}>{selectedArt.description}</Text>)}
                {!!selectedArt?.timestamp && (<Text style={{ fontSize: 12, color: '#888', marginTop: 10 }}>{selectedArt.timestamp}</Text>)}
             

                <View style={{ height: 1, backgroundColor: '#eee', marginVertical: 10 }} />
                <ScrollView
                  style={{ maxHeight: 220 }}
                  keyboardShouldPersistTaps="handled"
                  decelerationRate={Platform.OS === 'ios' ? 'fast' : 0.98}
                  scrollEventThrottle={16}
                  showsVerticalScrollIndicator
                >
                  {(artComments || []).map((c) => (
                    <View key={c.id} style={{ flexDirection: 'row', marginBottom: 10 }}>
                      <Image source={{ uri: c.user?.avatar }} style={{ width: 32, height: 32, borderRadius: 16, marginRight: 8 }} />
                      <View style={{ flex: 1 }}>
                        <Text style={{ fontWeight: 'bold' }}>{c.user?.name}</Text>
                        <Text>{c.text}</Text>
                        {!!c.timestamp && (<Text style={{ fontSize: 12, color: '#888', marginTop: 2 }}>{c.timestamp}</Text>)}
                      </View>
                    </View>
                  ))}
                </ScrollView>
                <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 8 }}>
                  <TextInput
                    style={[styles.input, { flex: 1, marginRight: 8 }]}
                    placeholder="Add a comment..."
                    value={artNewComment}
                    onChangeText={setArtNewComment}
                  />
                  <TouchableOpacity onPress={postArtComment} style={styles.saveButton}>
                    <Text style={styles.saveButtonText}>Send</Text>
                  </TouchableOpacity>
                </View>
              </View>
            </ScrollView>
          </View>
        </View>
      </Modal>


      {/* Artwork Upload Modal */}
      <Modal
        visible={artModalVisible}
        animationType="slide"
        transparent
        onRequestClose={() => setArtModalVisible(false)}
      >
        <KeyboardAvoidingView 
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={{ flex: 1 }}
        >
          <View style={styles.uploadModalOverlay}>
            <View style={styles.uploadModalContent}>
              <View style={styles.uploadModalHeader}>
                <Text style={styles.uploadModalTitle}>Upload Artwork</Text>
                <TouchableOpacity onPress={() => setArtModalVisible(false)}>
                  <Ionicons name="close" size={24} color="#333" />
                </TouchableOpacity>
              </View>

              <ScrollView style={styles.uploadModalBody} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
              {/* Image Picker */}
              <TouchableOpacity style={styles.uploadImagePicker} onPress={pickArtworkImage}>
                {artImage ? (
                  <Image source={artImage} style={styles.uploadPickedImage} />
                ) : (
                  <View style={styles.uploadImagePlaceholder}>
                    <Ionicons name="image-outline" size={48} color="#A68C7B" />
                    <Text style={styles.uploadImageText}>Tap to select image</Text>
                  </View>
                )}
              </TouchableOpacity>

              {/* Title Input */}
              <Text style={styles.uploadInputLabel}>Title *</Text>
              <TextInput
                style={styles.uploadInput}
                placeholder="Enter artwork title"
                value={artTitle}
                onChangeText={setArtTitle}
              />

              {/* Medium Input */}
              <Text style={styles.uploadInputLabel}>Medium</Text>
              <TextInput
                style={styles.uploadInput}
                placeholder="e.g., Oil, Digital, Watercolor"
                value={artMedium}
                onChangeText={setArtMedium}
              />

              {/* Description Input */}
              <Text style={styles.uploadInputLabel}>Description</Text>
              <TextInput
                style={[styles.uploadInput, styles.uploadTextArea]}
                placeholder="Enter description"
                value={artDescription}
                onChangeText={setArtDescription}
                multiline
                numberOfLines={4}
              />

              {/* Upload Button */}
              <TouchableOpacity
                style={[styles.uploadButton, artUploading && styles.uploadButtonDisabled]}
                onPress={submitArtwork}
                disabled={artUploading}
              >
                <Text style={styles.uploadButtonText}>
                  {artUploading ? 'Uploading...' : 'Upload Artwork'}
                </Text>
              </TouchableOpacity>
            </ScrollView>
          </View>
        </View>
        </KeyboardAvoidingView>
      </Modal>


      {/* Edit Profile Modal */}
      <Modal visible={modalVisible} animationType="slide" transparent onRequestClose={() => setModalVisible(false)}>
        <KeyboardAvoidingView 
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={{ flex: 1 }}
        >
          <View style={styles.uploadModalOverlay}>
            <View style={styles.uploadModalContent}>
              <View style={styles.uploadModalHeader}>
                <Text style={styles.uploadModalTitle}>Edit Profile</Text>
                <TouchableOpacity onPress={() => setModalVisible(false)}>
                  <Ionicons name="close" size={24} color="#333" />
                </TouchableOpacity>
              </View>

              <ScrollView style={styles.uploadModalBody} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
                <Text style={styles.uploadInputLabel}>Profile Photo</Text>
                <TouchableOpacity onPress={pickImage} style={styles.uploadImagePicker}>
                  {tempImage ? (
                    <Image source={tempImage} style={styles.uploadPickedImage} />
                  ) : (
                    <View style={styles.uploadImagePlaceholder}>
                      <Ionicons name="person-circle-outline" size={48} color="#A68C7B" />
                      <Text style={styles.uploadImageText}>Tap to change photo</Text>
                    </View>
                  )}
                </TouchableOpacity>

                <Text style={styles.uploadInputLabel}>Cover Photo</Text>
                <TouchableOpacity onPress={pickBackgroundImage} style={styles.uploadImagePicker}>
                  {tempBackgroundImage ? (
                    <Image source={{ uri: tempBackgroundImage.uri }} style={styles.uploadPickedImage} />
                  ) : (
                    <View style={styles.uploadImagePlaceholder}>
                      <Ionicons name="image-outline" size={48} color="#A68C7B" />
                      <Text style={styles.uploadImageText}>Tap to change cover</Text>
                    </View>
                  )}
                </TouchableOpacity>

                <Text style={styles.uploadInputLabel}>First Name</Text>
                <TextInput style={styles.uploadInput} placeholder="First Name" value={tempFirstName} onChangeText={setTempFirstName} />

                <Text style={styles.uploadInputLabel}>Middle Name</Text>
                <TextInput style={styles.uploadInput} placeholder="Middle Name" value={tempMiddleName} onChangeText={setTempMiddleName} />

                <Text style={styles.uploadInputLabel}>Last Name</Text>
                <TextInput style={styles.uploadInput} placeholder="Last Name" value={tempLastName} onChangeText={setTempLastName} />

                <Text style={styles.uploadInputLabel}>Username</Text>
                <TextInput style={styles.uploadInput} placeholder="Username" value={tempUserNameField} onChangeText={setTempUserNameField} />

                <Text style={styles.uploadInputLabel}>Sex</Text>
                <TouchableOpacity style={styles.uploadInput} onPress={() => setShowSexDropdown(!showSexDropdown)}>
                  <Text style={{ color: tempSex ? "#000" : "#999" }}>{tempSex || "Select Sex"}</Text>
                  <Ionicons name={showSexDropdown ? "chevron-up" : "chevron-down"} size={20} color="#555" style={{ position: "absolute", right: 12, top: 12 }} />
                </TouchableOpacity>
                {showSexDropdown && (
                  <View style={styles.categoryDropdown}>
                    {["Male", "Female", "PreferNotToSay"].map((item) => (
                      <TouchableOpacity key={item} style={styles.categoryItem} onPress={() => { setTempSex(item); setShowSexDropdown(false); }}>
                        <Text style={styles.categoryItemText}>{item}</Text>
                      </TouchableOpacity>
                    ))}
                  </View>
                )}

                <Text style={styles.uploadInputLabel}>Birthday</Text>
                <TouchableOpacity style={styles.uploadInput} onPress={() => setShowDatePicker(true)}>
                  <Text style={{ color: tempBirthday ? "#000" : "#999" }}>
                    {tempBirthday ? formattedTempDate : "Select your birthday"}
                  </Text>
                </TouchableOpacity>
                {showDatePicker && (
                  <DateTimePicker value={tempBirthday} mode="date" display="default" onChange={onChangeTempDate} />
                )}

                <Text style={styles.uploadInputLabel}>Address</Text>
                <TextInput style={styles.uploadInput} placeholder="Enter your address" value={tempAddress} onChangeText={setTempAddress} />

                <Text style={styles.uploadInputLabel}>Bio</Text>
                <TextInput style={styles.uploadInput} placeholder="Enter your bio" value={tempBio} onChangeText={setTempBio} />

                <Text style={styles.uploadInputLabel}>About</Text>
                <TextInput style={[styles.uploadInput, styles.uploadTextArea]} placeholder="Write something about yourself" multiline value={tempAbout} onChangeText={setTempAbout} />

                <TouchableOpacity style={styles.uploadButton} onPress={handleSave}>
                  <Text style={styles.uploadButtonText}>Save Changes</Text>
                </TouchableOpacity>
              </ScrollView>
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>
      </ScrollView>
    </SafeAreaView>
  );
}


const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#fff" },
  scrollContent: { flex: 1 },
  profileSection: { alignItems: "center", marginTop: 10, padding: 0 },
  backgroundImage: {
    width: "100%",
    height: 150,
    borderTopLeftRadius: 15,
    borderTopRightRadius: 15,
    resizeMode: "cover",
    marginBottom: -50,
  },
  avatarContainer: { position: "relative", top: -50, alignItems: "center" },
  avatar: {
    width: 100,
    height: 100,
    borderRadius: 50,
    borderWidth: 3,
    borderColor: "#fff",
  },
  name: { fontSize: 20, fontWeight: "bold", marginTop: -30 },
  detail: { fontSize: 14, color: "#000", textAlign: "center", marginVertical: 2 },
  detailLabel: { color: "#A68C7B", fontWeight: "600" },
  infoContainer: {
    backgroundColor: "#f9f9f9",
    borderWidth: 1,
    borderColor: "#D2AE7E",
    borderRadius: 10,
    padding: 12,
    marginVertical: 10,
    marginHorizontal: 20,
    width: "90%",
  },
  buttonContainer: { 
    alignItems: "center", 
    marginTop: 10 
  },
  buttonRow: { flexDirection: "row" },
  button: {
    backgroundColor: "#A68C7B",
    paddingVertical: 8,
    paddingHorizontal: 20,
    borderRadius: 20,
    marginHorizontal: 5,
  },
  buttonText: { fontSize: 14, fontWeight: "600", color: "#fff" },
  fullWidthButton: {
    marginTop: 10,
    alignSelf: "stretch",
    marginHorizontal: 5,
    alignItems: "center",
    justifyContent: "center",
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: "bold",
    marginHorizontal: 15,
    marginTop: 25,
    marginBottom: 10,
  },
  galleryRow: { flexDirection: "row", paddingHorizontal: 10 },
  galleryItem: {
    width: 100,
    height: 100,
    borderRadius: 10,
    marginRight: 10,
  },
  artworkPreview: {
    width: 120,
    height: 120,
    borderRadius: 12,
    backgroundColor: '#f0f0f0',
  },
  addImageBox: {
    width: 100,
    height: 100,
    borderRadius: 10,
    borderWidth: 2,
    borderColor: "#D2AE7E",
    alignItems: "center",
    justifyContent: "center",
    marginRight: 10,
  },
  addImageText: { fontSize: 32, color: "#D2AE7E" },
  fullScreenContainer: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.9)",
    justifyContent: "center",
    alignItems: "center",
  },
  fullScreenImage: { width: "90%", height: "80%" },
  modalOverlay: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "rgba(0,0,0,0.4)",
  },
  keyboardView: { flex: 1, width: "100%" },
  modalBox: {
    backgroundColor: "#fff",
    padding: 20,
    borderRadius: 15,
    elevation: 5,
    alignItems: "center",
    
  },
  modalTitle: { fontSize: 18, fontWeight: "bold", marginTop: 30, marginBottom: 15 },
  imagePicker: { alignItems: "center", marginVertical: 10 },
  avatarEdit: { width: 90, height: 90, borderRadius: 45 },
  changePhotoText: { textAlign: "center", color: "#007BFF", marginTop: 5, marginBottom: 10 },
  input: {
    backgroundColor: "#f9f9f9",
    borderWidth: 1,
    borderColor: "#ccc",
    borderRadius: 10,
    padding: 10,
    marginVertical: 5,
    width: "100%",
  },
  inputContainer: { width: "100%", position: "relative" },
  dropdownList: {
    width: "100%",
    backgroundColor: "#fff",
    borderWidth: 1,
    borderColor: "#ccc",
    borderRadius: 10,
    marginTop: -5,
    elevation: 3,
    zIndex: 10,
  },
  dropdownItem: {
    paddingVertical: 12,
    paddingHorizontal: 10,
    borderBottomWidth: 1,
    borderBottomColor: "#eee",
  },
  dropdownItemText: { fontSize: 16, color: "#000" },
  modalButtons: {
    flexDirection: "row",
    justifyContent: "space-between",
    marginTop: 15,
    width: "100%",
  },
  saveButton: {
    backgroundColor: "#A68C7B",
    paddingVertical: 8,
    paddingHorizontal: 25,
    borderRadius: 20,
  },
  saveButtonText: { color: "#fff", fontWeight: "bold" },
  cancelButton: {
    backgroundColor: "#eee",
    paddingVertical: 8,
    paddingHorizontal: 25,
    borderRadius: 20,
  },
  cancelButtonText: { color: "black", fontWeight: "bold" },
  placeholderCircle: {
    backgroundColor: "#f0f0f0",
    justifyContent: "center",
    alignItems: "center",
    borderWidth: 1,
    borderColor: "#ddd",
  },
  backgroundPreviewContainer: {
    width: 300,
    height: 100,
    borderRadius: 10,
    overflow: "hidden",
    backgroundColor: "#f0f0f0",
    justifyContent: "center",
    alignItems: "center",
    alignSelf: "center",
  },
  backgroundPreviewImage: { width: "100%", height: "100%" },
  artModalImage: {
    width: '100%',
    height: 260,
    resizeMode: 'cover',
    borderWidth: 3, // you can change thickness
    borderColor: '#fff', // change to your preferred color (e.g. '#000' or '#fff')
    borderRadius: 10, // optional for rounded corners
  },
  validIdPreview: {
    width: 200,        // Your desired width
    height: 120,       // You can adjust the height as well
    borderRadius: 12,
    backgroundColor: '#f0f0f0',
  },
  modalCloseButton: {
    position: 'absolute',
    top: 8,
    right: 8,
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: 'rgba(0,0,0,0.6)',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 2,
  },
  pendingButton: {
    backgroundColor: '#FFC107',
    opacity: 0.8,
  },
  uploadModalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  uploadModalContent: {
    backgroundColor: '#fff',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: '90%',
  },
  uploadModalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  uploadModalTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#A68C7B',
  },
  uploadModalBody: {
    padding: 20,
  },
  uploadImagePicker: {
    width: '100%',
    height: 200,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#A68C7B',
    borderStyle: 'dashed',
    marginBottom: 20,
    overflow: 'hidden',
  },
  uploadImagePlaceholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f9f9f9',
  },
  uploadImageText: {
    marginTop: 10,
    fontSize: 14,
    color: '#A68C7B',
  },
  uploadPickedImage: {
    width: '100%',
    height: '100%',
    resizeMode: 'cover',
  },
  uploadInputLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  uploadInput: {
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 8,
    padding: 12,
    fontSize: 14,
    marginBottom: 16,
    backgroundColor: '#fff',
  },
  uploadTextArea: {
    height: 100,
    textAlignVertical: 'top',
  },
  uploadButton: {
    backgroundColor: '#A68C7B',
    paddingVertical: 15,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 10,
    marginBottom: 20,
  },
  uploadButtonDisabled: {
    opacity: 0.6,
  },
  uploadButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  categoryDropdown: {
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 8,
    marginTop: -8,
    marginBottom: 16,
    elevation: 3,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  categoryItem: {
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  categoryItemText: {
    fontSize: 14,
    color: '#333',
  },
});
