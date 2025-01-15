//  ContentView.swift
//  DashBoard
//
//  Created by Barraud on 22/12/2024.

import SwiftUI
import AVFoundation
import Speech

import UIKit

struct Project: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var details: String
    var imageData: Data?
    
    init(id: UUID = UUID(), title: String, details: String, image: UIImage? = nil) {
        self.id = id
        self.title = title
        self.details = details
        self.imageData = image?.pngData()
    }

  
    var image: UIImage? {
        get {
            guard let imageData else { return nil }
            return UIImage(data: imageData)
        }
        set {
            imageData = newValue?.pngData()
        }
    }

   
    static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.details == rhs.details &&
               lhs.imageData == rhs.imageData
    }
}


extension UserDefaults {
    func saveProjects(_ projects: [Project]) {
        if let encoded = try? JSONEncoder().encode(projects) {
            set(encoded, forKey: "projects")
        }
    }
    
    func loadProjects() -> [Project] {
        if let data = data(forKey: "projects"),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            return decoded
        }
        return []
    }
}

struct ContentView: View {
    @State private var isRecording = false
    @State private var transcription = "Press the button and start speaking..."
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioSession: AVAudioSession!
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var speechRecognizer: SFSpeechRecognizer?
    @State private var projects: [Project] = []
    @State private var selectedProject: Project?
    private var audioEngine = AVAudioEngine()
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Text("Dash")
                        .font(.title2)
                        .padding()
                    Spacer()
                    NavigationLink(destination: ProjectsView(projects: $projects)) {
                        Image(systemName: "list.bullet")
                            .font(.title2)
                            .foregroundColor(.black)
                            .padding()
                    }
                }
                .padding(.top, 10)
                .background(Color.white.opacity(0.9))
                
                Spacer()
                
                // Bouton d'enregistrement
                Button(action: {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                    isRecording.toggle()
                }) {
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                        .font(.headline)
                        .padding()
                        .foregroundColor(.white)
                        .frame(width: 250, height: 60)
                        .background(isRecording ? Color.red : Color.green)
                        .cornerRadius(30)
                        .shadow(radius: 10)
                        .scaleEffect(isRecording ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2), value: isRecording)
                }
                .padding(.top, 50)
                
                // Zone de transcription
                Text(transcription)
                    .font(.title3)
                    .padding()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                Spacer()
                
                // Ajouter un nouveau projet
                Button(action: {
                    addProject()
                }) {
                    Text("Add New Project")
                        .font(.headline)
                        .padding()
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .cornerRadius(25)
                        .shadow(radius: 10)
                }
                .padding(.bottom, 50)
            }
            .navigationBarHidden(true)
            .onAppear {
                setupAudioSession()
                requestSpeechRecognitionAuthorization()
                loadProjects()
            }
            .onChange(of: projects) {
                saveProjects()
            }        }
    }
    
    func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup error: \(error.localizedDescription)")
        }
    }
    
    func requestSpeechRecognitionAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
                case .denied, .restricted, .notDetermined:
                    self.transcription = "Speech recognition authorization denied."
                @unknown default:
                    self.transcription = "Unknown authorization status."
                }
            }
        }
    }
    
    func startRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            transcription = "Speech recognizer is unavailable."
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            transcription = "Unable to create a recognition request."
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            transcription = "Invalid audio format: Sample rate or channel count is invalid."
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            transcription = "Listening..."
        } catch {
            transcription = "Audio engine couldn't start: \(error.localizedDescription)"
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                self.transcription = result.bestTranscription.formattedString
            }
            if let error = error {
                print("Recognition error: \(error.localizedDescription)")
                self.stopRecording()
            }
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        transcription = "Press the button and start speaking..."
    }
    
    func addProject() {
        let newProject = Project(id: UUID(), title: "New Project", details: transcription)
        projects.append(newProject)
        transcription = "Press the button and start speaking..."
        saveProjects()
    }

    func loadProjects() {
        projects = UserDefaults.standard.loadProjects()
    }
    
    func saveProjects() {
        UserDefaults.standard.saveProjects(projects)
    }
}

struct ProjectsView: View {
    @Binding var projects: [Project]
    
    var body: some View {
        List {
            ForEach(projects.indices, id: \.self) { index in
                
                NavigationLink(destination: ProjectDetailView(project: $projects[index])) {
                    VStack(alignment: .leading) {
                        Text(projects[index].title)
                            .font(.headline)
                        Text(projects[index].details)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onDelete(perform: deleteProject)
        }
        .navigationTitle("Projects")
    }
    
    func deleteProject(at offsets: IndexSet) {
        projects.remove(atOffsets: offsets)
    }
}


struct ProjectDetailView: View {
    @Binding var project: Project
    @Environment(\.presentationMode) var presentationMode

    @State private var localProject: Project
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? = nil

    init(project: Binding<Project>) {
        self._project = project
        self._localProject = State(initialValue: project.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TextField("Title", text: $localProject.title)
                .font(.title)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

            TextEditor(text: $localProject.details)
                .font(.body)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

            if let image = localProject.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                    .padding(.vertical)
            } else {
                Text("No image selected")
                    .foregroundColor(.gray)
            }

            Button(action: {
                showImagePicker = true
            }) {
                Text("Select Image")
                    .font(.headline)
                    .padding()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }

            Spacer()

            Button(action: {
                saveChanges()
            }) {
                Text("Save")
                    .font(.headline)
                    .padding()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(10)
            }
        }
        .padding()
        .navigationTitle("Project Details")
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $localProject.image)
        }
    }

    func saveChanges() {
        project = localProject
        presentationMode.wrappedValue.dismiss()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }
    }
}

