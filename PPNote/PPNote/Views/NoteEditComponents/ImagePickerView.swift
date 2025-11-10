import SwiftUI
import PhotosUI

// MARK: - Image Picker View
struct ImagePickerView: View {
    @Binding var showingCamera: Bool
    @Binding var showingPhotoLibrary: Bool
    @Binding var showingFilePicker: Bool
    @Binding var selectedImageItem: PhotosPickerItem?
    @Binding var selectedImageData: Data?
    let onImageSelected: (Data, String) -> Void

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Chọn hình ảnh")
                    .font(.headline)
                    .padding(.top, 20)

                VStack(spacing: 16) {
                    Button(action: {
                        showingCamera = true
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            
                            Text("Chụp ảnh")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    
                    Button(action: {
                        showingPhotoLibrary = true
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            
                            Text("Thư viện ảnh")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    
                    Button(action: {
                        showingFilePicker = true
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            
                            Text("Chọn tệp")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Chèn hình ảnh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Hủy") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}