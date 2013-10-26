//
//  dllmain.m
//  JSKit
//
//  Created by Pauli Ojala on 9.9.2008.
//  Copyright 2008 Lacquer oy/ltd. All rights reserved.
//


#import <windows.h>

__declspec(dllimport) int OBJCRegisterDLL(HINSTANCE handle);

int APIENTRY DllMain(HINSTANCE handle, DWORD reason, LPVOID _reserved) {

   if(reason==DLL_PROCESS_ATTACH)
    return OBJCRegisterDLL(handle);

   return TRUE;
}
