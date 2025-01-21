// FileUploader.js
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Image,
  Alert,
} from 'react-native';
import * as DocumentPicker from 'expo-document-picker';
import * as ImagePicker from 'expo-image-picker';
import { MaterialIcons } from '@expo/vector-icons';
import theme from '../styles/theme';

/**
 * FileUploader Component
 *
 * @param {Object} props - Props for the FileUploader component.
 * @param {Function} props.onFileSelect - Callback when a file is selected.
 * @param {Array} props.allowedTypes - Array of allowed MIME types (e.g., ['image/jpeg', 'application/pdf']).
 * @param {boolean} props.preview - Whether to show a preview of the selected file.
 * @param {Object} props.style - Additional styles for the component.
 * @returns {JSX.Element}
 */
const FileUploader = ({
  onFileSelect,
  allowedTypes = ['image/jpeg', 'image/png', 'application/pdf'],
  preview = true,
  style = {},
}) => {
  const [file, setFile] = useState(null);

  const handleFileSelection = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: allowedTypes.join(','),
      });

      if (result.type === 'cancel') return; // User canceled the picker

      // Validate file type
      if (!allowedTypes.includes(result.mimeType)) {
        Alert.alert('Invalid File Type', 'Please select a valid file type.');
        return;
      }

      setFile(result);
      if (onFileSelect) onFileSelect(result);
    } catch (error) {
      console.error('Error selecting file:', error);
      Alert.alert('Error', 'An error occurred while selecting the file.');
    }
  };

  const handleImageSelection = async () => {
    try {
      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: true,
        quality: 1,
      });

      if (!result.canceled) {
        const selectedImage = result.assets[0];
        setFile(selectedImage);
        if (onFileSelect) onFileSelect(selectedImage);
      }
    } catch (error) {
      console.error('Error selecting image:', error);
      Alert.alert('Error', 'An error occurred while selecting the image.');
    }
  };

  return (
    <View style={[styles.container, style]}>
      <TouchableOpacity style={styles.button} onPress={handleFileSelection}>
        <MaterialIcons name="attach-file" size={24} color={theme.colors.primary} />
        <Text style={styles.buttonText}>Upload File</Text>
      </TouchableOpacity>
      <TouchableOpacity style={styles.button} onPress={handleImageSelection}>
        <MaterialIcons name="image" size={24} color={theme.colors.primary} />
        <Text style={styles.buttonText}>Upload Image</Text>
      </TouchableOpacity>

      {preview && file && (
        <View style={styles.previewContainer}>
          {file.uri ? (
            <Image source={{ uri: file.uri }} style={styles.previewImage} />
          ) : (
            <Text style={styles.previewText}>File: {file.name}</Text>
          )}
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    padding: theme.spacing.md,
    backgroundColor: theme.colors.surface,
    borderRadius: theme.borderRadius.md,
    ...theme.shadows.light,
  },
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: theme.spacing.sm,
    paddingHorizontal: theme.spacing.md,
    backgroundColor: theme.colors.background,
    borderRadius: theme.borderRadius.sm,
    marginBottom: theme.spacing.sm,
  },
  buttonText: {
    marginLeft: theme.spacing.sm,
    fontSize: theme.fontSizes.md,
    color: theme.colors.primary,
  },
  previewContainer: {
    marginTop: theme.spacing.md,
    alignItems: 'center',
  },
  previewImage: {
    width: 100,
    height: 100,
    borderRadius: theme.borderRadius.sm,
    marginBottom: theme.spacing.sm,
  },
  previewText: {
    fontSize: theme.fontSizes.sm,
    color: theme.colors.text,
  },
});

export default FileUploader;