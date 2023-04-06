import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:image_picker/image_picker.dart';

import 'package:shared_preferences/shared_preferences.dart';

class FormScreen extends StatefulWidget {
  @override
  FormScreenState createState() => FormScreenState();
}

class FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedOption;
  File? _imageFile;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Form'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FormBuilder(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              FormBuilderTextField(
                name: 'name',
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: FormBuilderValidators.required(),
              ),
              FormBuilderTextField(
                name: 'email',
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  FormBuilderValidators.email(),
                ]),
              ),
              FormBuilderTextField(
                name: 'phone',
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: FormBuilderValidators.required(),
              ),
              FormBuilderDropdown(
                name: 'option',
                decoration: const InputDecoration(labelText: 'Option'),
                items: ['1', '2', '3', '4']
                    .map((option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedOption = value.toString();
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Image:'),
                  _imageFile != null
                      ? Image.file(
                    _imageFile!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                      : TextButton(
                    onPressed: _selectImage,
                    child: const Text('Select Image'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveForm,
                child: _isSaving ? const CircularProgressIndicator() : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    setState(() {
      _imageFile = pickedFile != null ? File(pickedFile.path) : null;
    });
  }

  void _saveForm() async {
    if (_formKey.currentState!.saveAndValidate()) {
      setState(() {
        _isSaving = true;
      });

      final name = _nameController.text;
      final email = _emailController.text;
      final phone = _phoneController.text;

      final data = {
        'name': name,
        'email': email,
        'phone': phone,
        'option': _selectedOption,
      };

      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        final imageUrl = await _uploadImageToFirebase(bytes);
        data['imageUrl'] = imageUrl;
      }

      await _saveFormDataToLocalStorage(data);

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Form data saved locally.'),
        ),
      );
    }
  }

  Future<String?> _uploadImageToFirebase(List<int> bytes) async {
    final firebaseStorageRef = FirebaseStorage.instance.ref().child('images/$build');
    final uploadTask = firebaseStorageRef.putData(Uint8List.fromList( bytes ));
    final snapshot = await uploadTask.whenComplete(() {});

    final imageUrl = await snapshot.ref.getDownloadURL();
    return imageUrl;
  }

  Future<void> _saveFormDataToLocalStorage(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final formData = prefs.getStringList('formData') ?? [];
    formData.add(jsonEncode(data));
    await prefs.setStringList('formData', formData);
  }
}
