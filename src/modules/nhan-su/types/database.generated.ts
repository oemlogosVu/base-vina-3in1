export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      allowance_types: {
        Row: {
          code: string
          created_at: string
          ghi_chu: string | null
          id: string
          is_active: boolean
          is_insurance: boolean
          is_taxable: boolean
          name: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          ghi_chu?: string | null
          id?: string
          is_active?: boolean
          is_insurance?: boolean
          is_taxable?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          ghi_chu?: string | null
          id?: string
          is_active?: boolean
          is_insurance?: boolean
          is_taxable?: boolean
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      app_users: {
        Row: {
          created_at: string
          duyet_cong: boolean
          employee_id: string | null
          full_name: string
          id: string
          is_active: boolean
          quan_ly_to_doi: boolean
          quyen: string[] | null
          role: Database["public"]["Enums"]["user_role"]
          tabs: string[] | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          duyet_cong?: boolean
          employee_id?: string | null
          full_name: string
          id: string
          is_active?: boolean
          quan_ly_to_doi?: boolean
          quyen?: string[] | null
          role?: Database["public"]["Enums"]["user_role"]
          tabs?: string[] | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          duyet_cong?: boolean
          employee_id?: string | null
          full_name?: string
          id?: string
          is_active?: boolean
          quan_ly_to_doi?: boolean
          quyen?: string[] | null
          role?: Database["public"]["Enums"]["user_role"]
          tabs?: string[] | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_app_users_employee"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      attendance_days: {
        Row: {
          created_at: string
          early_leave_minutes: number
          employee_id: string
          first_in: string | null
          id: string
          last_out: string | null
          late_minutes: number
          ot_first_in: string | null
          ot_last_out: string | null
          ot_minutes: number
          shift_id: string | null
          status: Database["public"]["Enums"]["attendance_day_status"]
          tong_hop_luc: string | null
          ty_le_lam_them_pct: number | null
          updated_at: string
          work_date: string
          worked_minutes: number
        }
        Insert: {
          created_at?: string
          early_leave_minutes?: number
          employee_id: string
          first_in?: string | null
          id?: string
          last_out?: string | null
          late_minutes?: number
          ot_first_in?: string | null
          ot_last_out?: string | null
          ot_minutes?: number
          shift_id?: string | null
          status?: Database["public"]["Enums"]["attendance_day_status"]
          tong_hop_luc?: string | null
          ty_le_lam_them_pct?: number | null
          updated_at?: string
          work_date: string
          worked_minutes?: number
        }
        Update: {
          created_at?: string
          early_leave_minutes?: number
          employee_id?: string
          first_in?: string | null
          id?: string
          last_out?: string | null
          late_minutes?: number
          ot_first_in?: string | null
          ot_last_out?: string | null
          ot_minutes?: number
          shift_id?: string | null
          status?: Database["public"]["Enums"]["attendance_day_status"]
          tong_hop_luc?: string | null
          ty_le_lam_them_pct?: number | null
          updated_at?: string
          work_date?: string
          worked_minutes?: number
        }
        Relationships: [
          {
            foreignKeyName: "attendance_days_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_days_shift_id_fkey"
            columns: ["shift_id"]
            isOneToOne: false
            referencedRelation: "work_shifts"
            referencedColumns: ["id"]
          },
        ]
      }
      attendance_logs: {
        Row: {
          check_type: Database["public"]["Enums"]["check_type"]
          created_at: string
          da_xac_nhan: boolean
          deleted_at: string | null
          deleted_by: string | null
          device_info: Json
          employee_id: string
          ghi_chu_xac_nhan: string | null
          id: string
          la_cham_bu: boolean
          logged_at: string
          ly_do_xoa: string | null
          selfie_path: string | null
          xac_nhan_boi: string | null
          xac_nhan_luc: string | null
        }
        Insert: {
          check_type: Database["public"]["Enums"]["check_type"]
          created_at?: string
          da_xac_nhan?: boolean
          deleted_at?: string | null
          deleted_by?: string | null
          device_info?: Json
          employee_id: string
          ghi_chu_xac_nhan?: string | null
          id?: string
          la_cham_bu?: boolean
          logged_at?: string
          ly_do_xoa?: string | null
          selfie_path?: string | null
          xac_nhan_boi?: string | null
          xac_nhan_luc?: string | null
        }
        Update: {
          check_type?: Database["public"]["Enums"]["check_type"]
          created_at?: string
          da_xac_nhan?: boolean
          deleted_at?: string | null
          deleted_by?: string | null
          device_info?: Json
          employee_id?: string
          ghi_chu_xac_nhan?: string | null
          id?: string
          la_cham_bu?: boolean
          logged_at?: string
          ly_do_xoa?: string | null
          selfie_path?: string | null
          xac_nhan_boi?: string | null
          xac_nhan_luc?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "attendance_logs_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_logs_xac_nhan_boi_fkey"
            columns: ["xac_nhan_boi"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
        ]
      }
      bang_thanh_toan_to: {
        Row: {
          created_at: string
          den_ngay: string
          dong_cho_duyet: number
          ghi_chu: string | null
          id: string
          nguoi_tao: string
          tao_luc: string
          to_doi_id: string
          tu_ngay: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          den_ngay: string
          dong_cho_duyet?: number
          ghi_chu?: string | null
          id?: string
          nguoi_tao: string
          tao_luc?: string
          to_doi_id: string
          tu_ngay: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          den_ngay?: string
          dong_cho_duyet?: number
          ghi_chu?: string | null
          id?: string
          nguoi_tao?: string
          tao_luc?: string
          to_doi_id?: string
          tu_ngay?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bang_thanh_toan_to_nguoi_tao_fkey"
            columns: ["nguoi_tao"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bang_thanh_toan_to_to_doi_id_fkey"
            columns: ["to_doi_id"]
            isOneToOne: false
            referencedRelation: "to_doi"
            referencedColumns: ["id"]
          },
        ]
      }
      ca_cong_nhat: {
        Row: {
          company_id: string
          created_at: string
          gio_bat_dau: string
          gio_ket_thuc: string
          id: string
          is_active: boolean
          ma: string
          updated_at: string
        }
        Insert: {
          company_id: string
          created_at?: string
          gio_bat_dau: string
          gio_ket_thuc: string
          id?: string
          is_active?: boolean
          ma: string
          updated_at?: string
        }
        Update: {
          company_id?: string
          created_at?: string
          gio_bat_dau?: string
          gio_ket_thuc?: string
          id?: string
          is_active?: boolean
          ma?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "ca_cong_nhat_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      cfg_base_salary: {
        Row: {
          amount: number
          created_at: string
          effective_from: string
          id: string
        }
        Insert: {
          amount: number
          created_at?: string
          effective_from: string
          id?: string
        }
        Update: {
          amount?: number
          created_at?: string
          effective_from?: string
          id?: string
        }
        Relationships: []
      }
      cfg_insurance_rates: {
        Row: {
          bhtn_cap_multiple: number
          bhtn_employee_pct: number
          bhtn_employer_pct: number
          bhxh_cap_multiple: number
          bhxh_employee_pct: number
          bhxh_employer_pct: number
          bhyt_employee_pct: number
          bhyt_employer_pct: number
          created_at: string
          effective_from: string
          ghi_chu: string | null
          id: string
          nghi_khong_luong_mien_dong_ngay: number | null
        }
        Insert: {
          bhtn_cap_multiple: number
          bhtn_employee_pct: number
          bhtn_employer_pct: number
          bhxh_cap_multiple: number
          bhxh_employee_pct: number
          bhxh_employer_pct: number
          bhyt_employee_pct: number
          bhyt_employer_pct: number
          created_at?: string
          effective_from: string
          ghi_chu?: string | null
          id?: string
          nghi_khong_luong_mien_dong_ngay?: number | null
        }
        Update: {
          bhtn_cap_multiple?: number
          bhtn_employee_pct?: number
          bhtn_employer_pct?: number
          bhxh_cap_multiple?: number
          bhxh_employee_pct?: number
          bhxh_employer_pct?: number
          bhyt_employee_pct?: number
          bhyt_employer_pct?: number
          created_at?: string
          effective_from?: string
          ghi_chu?: string | null
          id?: string
          nghi_khong_luong_mien_dong_ngay?: number | null
        }
        Relationships: []
      }
      cfg_overtime_rates: {
        Row: {
          created_at: string
          effective_from: string
          ghi_chu: string | null
          id: string
          ngay_le_pct: number
          ngay_nghi_tuan_pct: number
          ngay_thuong_pct: number
        }
        Insert: {
          created_at?: string
          effective_from: string
          ghi_chu?: string | null
          id?: string
          ngay_le_pct: number
          ngay_nghi_tuan_pct: number
          ngay_thuong_pct: number
        }
        Update: {
          created_at?: string
          effective_from?: string
          ghi_chu?: string | null
          id?: string
          ngay_le_pct?: number
          ngay_nghi_tuan_pct?: number
          ngay_thuong_pct?: number
        }
        Relationships: []
      }
      cfg_pit_brackets: {
        Row: {
          created_at: string
          effective_from: string
          from_amount: number
          id: string
          level: number
          rate: number
          to_amount: number | null
        }
        Insert: {
          created_at?: string
          effective_from: string
          from_amount: number
          id?: string
          level: number
          rate: number
          to_amount?: number | null
        }
        Update: {
          created_at?: string
          effective_from?: string
          from_amount?: number
          id?: string
          level?: number
          rate?: number
          to_amount?: number | null
        }
        Relationships: []
      }
      cfg_pit_deductions: {
        Row: {
          created_at: string
          dependent_amount: number
          effective_from: string
          id: string
          personal_amount: number
        }
        Insert: {
          created_at?: string
          dependent_amount: number
          effective_from: string
          id?: string
          personal_amount: number
        }
        Update: {
          created_at?: string
          dependent_amount?: number
          effective_from?: string
          id?: string
          personal_amount?: number
        }
        Relationships: []
      }
      cfg_region_min_wage: {
        Row: {
          amount: number
          created_at: string
          effective_from: string
          id: string
          region: number
        }
        Insert: {
          amount: number
          created_at?: string
          effective_from: string
          id?: string
          region: number
        }
        Update: {
          amount?: number
          created_at?: string
          effective_from?: string
          id?: string
          region?: number
        }
        Relationships: []
      }
      cham_cong_cong_nhat: {
        Row: {
          ca_chieu_den: string | null
          ca_chieu_tu: string | null
          ca_sang_den: string | null
          ca_sang_tu: string | null
          ca_toi_den: string | null
          ca_toi_tu: string | null
          created_at: string
          employee_id: string
          ghi_chu: string | null
          id: string
          ngoai_gio_den: string | null
          ngoai_gio_tu: string | null
          phien_id: string
          so_cong: number | null
          so_gio: number | null
          so_gio_ot: number
          thuong: number
          thuong_ly_do: string | null
          updated_at: string
          work_date: string
        }
        Insert: {
          ca_chieu_den?: string | null
          ca_chieu_tu?: string | null
          ca_sang_den?: string | null
          ca_sang_tu?: string | null
          ca_toi_den?: string | null
          ca_toi_tu?: string | null
          created_at?: string
          employee_id: string
          ghi_chu?: string | null
          id?: string
          ngoai_gio_den?: string | null
          ngoai_gio_tu?: string | null
          phien_id: string
          so_cong?: number | null
          so_gio?: number | null
          so_gio_ot?: number
          thuong?: number
          thuong_ly_do?: string | null
          updated_at?: string
          work_date: string
        }
        Update: {
          ca_chieu_den?: string | null
          ca_chieu_tu?: string | null
          ca_sang_den?: string | null
          ca_sang_tu?: string | null
          ca_toi_den?: string | null
          ca_toi_tu?: string | null
          created_at?: string
          employee_id?: string
          ghi_chu?: string | null
          id?: string
          ngoai_gio_den?: string | null
          ngoai_gio_tu?: string | null
          phien_id?: string
          so_cong?: number | null
          so_gio?: number | null
          so_gio_ot?: number
          thuong?: number
          thuong_ly_do?: string | null
          updated_at?: string
          work_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "cccn_thuoc_phien"
            columns: ["phien_id", "work_date"]
            isOneToOne: false
            referencedRelation: "phien_cham_cong_to"
            referencedColumns: ["id", "work_date"]
          },
          {
            foreignKeyName: "cham_cong_cong_nhat_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      chung_tu: {
        Row: {
          doi_tuong_id: string
          duong_dan: string
          id: string
          kich_thuoc: number
          loai: Database["public"]["Enums"]["loai_chung_tu"]
          nguoi_tao: string
          sha256: string
          so_dong: number
          so_hieu: string
          tao_luc: string
          tieu_de: string
          tong_tien: number
        }
        Insert: {
          doi_tuong_id: string
          duong_dan: string
          id?: string
          kich_thuoc: number
          loai: Database["public"]["Enums"]["loai_chung_tu"]
          nguoi_tao: string
          sha256: string
          so_dong: number
          so_hieu: string
          tao_luc?: string
          tieu_de: string
          tong_tien: number
        }
        Update: {
          doi_tuong_id?: string
          duong_dan?: string
          id?: string
          kich_thuoc?: number
          loai?: Database["public"]["Enums"]["loai_chung_tu"]
          nguoi_tao?: string
          sha256?: string
          so_dong?: number
          so_hieu?: string
          tao_luc?: string
          tieu_de?: string
          tong_tien?: number
        }
        Relationships: [
          {
            foreignKeyName: "chung_tu_nguoi_tao_fkey"
            columns: ["nguoi_tao"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
        ]
      }
      companies: {
        Row: {
          address: string | null
          code: string
          created_at: string
          gio_ra: string | null
          gio_vao: string | null
          han_xac_nhan_phieu_ngay: number | null
          id: string
          is_active: boolean
          name: string
          nghi_den: string | null
          nghi_tu: string | null
          standard_days: number | null
          tax_code: string | null
          updated_at: string
        }
        Insert: {
          address?: string | null
          code: string
          created_at?: string
          gio_ra?: string | null
          gio_vao?: string | null
          han_xac_nhan_phieu_ngay?: number | null
          id?: string
          is_active?: boolean
          name: string
          nghi_den?: string | null
          nghi_tu?: string | null
          standard_days?: number | null
          tax_code?: string | null
          updated_at?: string
        }
        Update: {
          address?: string | null
          code?: string
          created_at?: string
          gio_ra?: string | null
          gio_vao?: string | null
          han_xac_nhan_phieu_ngay?: number | null
          id?: string
          is_active?: boolean
          name?: string
          nghi_den?: string | null
          nghi_tu?: string | null
          standard_days?: number | null
          tax_code?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      departments: {
        Row: {
          code: string
          company_id: string | null
          created_at: string
          id: string
          is_active: boolean
          manager_id: string | null
          name: string
          parent_id: string | null
          updated_at: string
        }
        Insert: {
          code: string
          company_id?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          manager_id?: string | null
          name: string
          parent_id?: string | null
          updated_at?: string
        }
        Update: {
          code?: string
          company_id?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          manager_id?: string | null
          name?: string
          parent_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "departments_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "departments_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "departments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_departments_manager"
            columns: ["manager_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      dependents: {
        Row: {
          created_at: string
          employee_id: string
          full_name: string
          id: string
          reg_from: string | null
          reg_to: string | null
          relationship: string | null
          tax_code: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          employee_id: string
          full_name: string
          id?: string
          reg_from?: string | null
          reg_to?: string | null
          relationship?: string | null
          tax_code?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          employee_id?: string
          full_name?: string
          id?: string
          reg_from?: string | null
          reg_to?: string | null
          relationship?: string | null
          tax_code?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "dependents_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      dong_thanh_toan_to: {
        Row: {
          bang_id: string
          created_at: string
          don_gia: number
          don_gia_ot: number
          employee_id: string
          ghi_chu: string | null
          id: string
          kieu_tinh: string
          so_gio_ot: number
          so_luong: number
          thanh_tien: number | null
          thuong: number
          updated_at: string
        }
        Insert: {
          bang_id: string
          created_at?: string
          don_gia: number
          don_gia_ot?: number
          employee_id: string
          ghi_chu?: string | null
          id?: string
          kieu_tinh?: string
          so_gio_ot?: number
          so_luong: number
          thanh_tien?: number | null
          thuong?: number
          updated_at?: string
        }
        Update: {
          bang_id?: string
          created_at?: string
          don_gia?: number
          don_gia_ot?: number
          employee_id?: string
          ghi_chu?: string | null
          id?: string
          kieu_tinh?: string
          so_gio_ot?: number
          so_luong?: number
          thanh_tien?: number | null
          thuong?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "dong_thanh_toan_to_bang_id_fkey"
            columns: ["bang_id"]
            isOneToOne: false
            referencedRelation: "bang_thanh_toan_to"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dong_thanh_toan_to_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      employee_documents: {
        Row: {
          doc_type: string
          employee_id: string
          file_path: string
          id: string
          note: string | null
          uploaded_at: string
        }
        Insert: {
          doc_type: string
          employee_id: string
          file_path: string
          id?: string
          note?: string | null
          uploaded_at?: string
        }
        Update: {
          doc_type?: string
          employee_id?: string
          file_path?: string
          id?: string
          note?: string | null
          uploaded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "employee_documents_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      employee_sensitive: {
        Row: {
          bank_account_no: string | null
          bank_name: string | null
          cccd: string | null
          cccd_issue_date: string | null
          cccd_issue_place: string | null
          created_at: string
          employee_id: string
          social_insurance_no: string | null
          tax_code: string | null
          updated_at: string
        }
        Insert: {
          bank_account_no?: string | null
          bank_name?: string | null
          cccd?: string | null
          cccd_issue_date?: string | null
          cccd_issue_place?: string | null
          created_at?: string
          employee_id: string
          social_insurance_no?: string | null
          tax_code?: string | null
          updated_at?: string
        }
        Update: {
          bank_account_no?: string | null
          bank_name?: string | null
          cccd?: string | null
          cccd_issue_date?: string | null
          cccd_issue_place?: string | null
          created_at?: string
          employee_id?: string
          social_insurance_no?: string | null
          tax_code?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "employee_sensitive_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: true
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      employees: {
        Row: {
          avatar_url: string | null
          company_id: string | null
          created_at: string
          deleted_at: string | null
          deleted_by: string | null
          department_id: string | null
          dob: string | null
          employee_code: string
          full_name: string
          gender: string | null
          hire_date: string | null
          id: string
          ly_do_xoa: string | null
          manager_id: string | null
          permanent_address: string | null
          personal_email: string | null
          phone: string | null
          region: number | null
          status: Database["public"]["Enums"]["employee_status"]
          theo_doi_cham_cong: boolean
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          company_id?: string | null
          created_at?: string
          deleted_at?: string | null
          deleted_by?: string | null
          department_id?: string | null
          dob?: string | null
          employee_code: string
          full_name: string
          gender?: string | null
          hire_date?: string | null
          id?: string
          ly_do_xoa?: string | null
          manager_id?: string | null
          permanent_address?: string | null
          personal_email?: string | null
          phone?: string | null
          region?: number | null
          status?: Database["public"]["Enums"]["employee_status"]
          theo_doi_cham_cong?: boolean
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          company_id?: string | null
          created_at?: string
          deleted_at?: string | null
          deleted_by?: string | null
          department_id?: string | null
          dob?: string | null
          employee_code?: string
          full_name?: string
          gender?: string | null
          hire_date?: string | null
          id?: string
          ly_do_xoa?: string | null
          manager_id?: string | null
          permanent_address?: string | null
          personal_email?: string | null
          phone?: string | null
          region?: number | null
          status?: Database["public"]["Enums"]["employee_status"]
          theo_doi_cham_cong?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "employees_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employees_department_id_fkey"
            columns: ["department_id"]
            isOneToOne: false
            referencedRelation: "departments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employees_manager_id_fkey"
            columns: ["manager_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      labor_contracts: {
        Row: {
          allowances: Json
          contract_no: string
          created_at: string
          employee_id: string
          end_date: string | null
          id: string
          is_active: boolean
          start_date: string
          type: Database["public"]["Enums"]["contract_type"]
          updated_at: string
        }
        Insert: {
          allowances?: Json
          contract_no: string
          created_at?: string
          employee_id: string
          end_date?: string | null
          id?: string
          is_active?: boolean
          start_date: string
          type: Database["public"]["Enums"]["contract_type"]
          updated_at?: string
        }
        Update: {
          allowances?: Json
          contract_no?: string
          created_at?: string
          employee_id?: string
          end_date?: string | null
          id?: string
          is_active?: boolean
          start_date?: string
          type?: Database["public"]["Enums"]["contract_type"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "labor_contracts_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      muc_luong_hop_dong: {
        Row: {
          bhxh_salary: number
          contract_id: string
          created_at: string
          dat_boi: string | null
          id: string
          ly_do: string | null
          position_salary: number
          tu_ngay: string
          updated_at: string
        }
        Insert: {
          bhxh_salary: number
          contract_id: string
          created_at?: string
          dat_boi?: string | null
          id?: string
          ly_do?: string | null
          position_salary: number
          tu_ngay: string
          updated_at?: string
        }
        Update: {
          bhxh_salary?: number
          contract_id?: string
          created_at?: string
          dat_boi?: string | null
          id?: string
          ly_do?: string | null
          position_salary?: number
          tu_ngay?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "muc_luong_hop_dong_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "labor_contracts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "muc_luong_hop_dong_dat_boi_fkey"
            columns: ["dat_boi"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
        ]
      }
      nhan_vien_chuc_danh: {
        Row: {
          created_at: string
          den_ngay: string | null
          employee_id: string
          id: string
          la_chinh: boolean
          ly_do: string | null
          position_id: string
          tu_ngay: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          den_ngay?: string | null
          employee_id: string
          id?: string
          la_chinh?: boolean
          ly_do?: string | null
          position_id: string
          tu_ngay: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          den_ngay?: string | null
          employee_id?: string
          id?: string
          la_chinh?: boolean
          ly_do?: string | null
          position_id?: string
          tu_ngay?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "nhan_vien_kiem_nhiem_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "nhan_vien_kiem_nhiem_position_id_fkey"
            columns: ["position_id"]
            isOneToOne: false
            referencedRelation: "positions"
            referencedColumns: ["id"]
          },
        ]
      }
      payroll_periods: {
        Row: {
          closed_at: string | null
          closed_by: string | null
          company_id: string
          created_at: string
          id: string
          month: number
          standard_days: number
          status: Database["public"]["Enums"]["period_status"]
          updated_at: string
          year: number
        }
        Insert: {
          closed_at?: string | null
          closed_by?: string | null
          company_id: string
          created_at?: string
          id?: string
          month: number
          standard_days: number
          status?: Database["public"]["Enums"]["period_status"]
          updated_at?: string
          year: number
        }
        Update: {
          closed_at?: string | null
          closed_by?: string | null
          company_id?: string
          created_at?: string
          id?: string
          month?: number
          standard_days?: number
          status?: Database["public"]["Enums"]["period_status"]
          updated_at?: string
          year?: number
        }
        Relationships: [
          {
            foreignKeyName: "payroll_periods_closed_by_fkey"
            columns: ["closed_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payroll_periods_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      payslip_items: {
        Row: {
          amount: number
          created_at: string
          id: string
          is_insurance: boolean
          is_taxable: boolean
          item_type: string
          name: string
          payslip_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          id?: string
          is_insurance?: boolean
          is_taxable?: boolean
          item_type: string
          name: string
          payslip_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          id?: string
          is_insurance?: boolean
          is_taxable?: boolean
          item_type?: string
          name?: string
          payslip_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "payslip_items_payslip_id_fkey"
            columns: ["payslip_id"]
            isOneToOne: false
            referencedRelation: "payslips"
            referencedColumns: ["id"]
          },
        ]
      }
      payslips: {
        Row: {
          assessable_income: number
          bhtn_employee: number
          bhtn_employer: number
          bhxh_employee: number
          bhxh_employer: number
          bhyt_employee: number
          bhyt_employer: number
          cfg_snapshot: Json
          created_at: string
          dependent_deduction: number
          employee_id: string
          gross_salary: number
          id: string
          luong_dong_bhxh: number | null
          muc_luong_snapshot: Json
          net_salary: number
          period_id: string
          personal_deduction: number
          pit: number
          taxable_income: number
          thac_mac_luc: string | null
          thac_mac_ly_do: string | null
          tinh_boi: string | null
          tinh_luc: string | null
          updated_at: string
          worked_days: number
          xac_nhan_luc: string | null
          xac_nhan_trang_thai: Database["public"]["Enums"]["payslip_ack"]
          xac_nhan_tu_dong: boolean
        }
        Insert: {
          assessable_income?: number
          bhtn_employee?: number
          bhtn_employer?: number
          bhxh_employee?: number
          bhxh_employer?: number
          bhyt_employee?: number
          bhyt_employer?: number
          cfg_snapshot?: Json
          created_at?: string
          dependent_deduction?: number
          employee_id: string
          gross_salary?: number
          id?: string
          luong_dong_bhxh?: number | null
          muc_luong_snapshot?: Json
          net_salary?: number
          period_id: string
          personal_deduction?: number
          pit?: number
          taxable_income?: number
          thac_mac_luc?: string | null
          thac_mac_ly_do?: string | null
          tinh_boi?: string | null
          tinh_luc?: string | null
          updated_at?: string
          worked_days?: number
          xac_nhan_luc?: string | null
          xac_nhan_trang_thai?: Database["public"]["Enums"]["payslip_ack"]
          xac_nhan_tu_dong?: boolean
        }
        Update: {
          assessable_income?: number
          bhtn_employee?: number
          bhtn_employer?: number
          bhxh_employee?: number
          bhxh_employer?: number
          bhyt_employee?: number
          bhyt_employer?: number
          cfg_snapshot?: Json
          created_at?: string
          dependent_deduction?: number
          employee_id?: string
          gross_salary?: number
          id?: string
          luong_dong_bhxh?: number | null
          muc_luong_snapshot?: Json
          net_salary?: number
          period_id?: string
          personal_deduction?: number
          pit?: number
          taxable_income?: number
          thac_mac_luc?: string | null
          thac_mac_ly_do?: string | null
          tinh_boi?: string | null
          tinh_luc?: string | null
          updated_at?: string
          worked_days?: number
          xac_nhan_luc?: string | null
          xac_nhan_trang_thai?: Database["public"]["Enums"]["payslip_ack"]
          xac_nhan_tu_dong?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "payslips_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payslips_period_id_fkey"
            columns: ["period_id"]
            isOneToOne: false
            referencedRelation: "payroll_periods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payslips_tinh_boi_fkey"
            columns: ["tinh_boi"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
        ]
      }
      phien_cham_cong_to: {
        Row: {
          anh_path: string | null
          cham_luc: string
          created_at: string
          da_duyet: boolean
          duyet_boi: string | null
          duyet_luc: string | null
          ghi_chu: string | null
          id: string
          nguoi_cham_id: string
          to_doi_id: string
          updated_at: string
          work_date: string
        }
        Insert: {
          anh_path?: string | null
          cham_luc?: string
          created_at?: string
          da_duyet?: boolean
          duyet_boi?: string | null
          duyet_luc?: string | null
          ghi_chu?: string | null
          id?: string
          nguoi_cham_id: string
          to_doi_id: string
          updated_at?: string
          work_date: string
        }
        Update: {
          anh_path?: string | null
          cham_luc?: string
          created_at?: string
          da_duyet?: boolean
          duyet_boi?: string | null
          duyet_luc?: string | null
          ghi_chu?: string | null
          id?: string
          nguoi_cham_id?: string
          to_doi_id?: string
          updated_at?: string
          work_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "phien_cham_cong_to_nguoi_cham_id_fkey"
            columns: ["nguoi_cham_id"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "phien_cham_cong_to_to_doi_id_fkey"
            columns: ["to_doi_id"]
            isOneToOne: false
            referencedRelation: "to_doi"
            referencedColumns: ["id"]
          },
        ]
      }
      position_allowances: {
        Row: {
          allowance_type_id: string
          amount: number
          created_at: string
          id: string
          position_id: string
          updated_at: string
        }
        Insert: {
          allowance_type_id: string
          amount: number
          created_at?: string
          id?: string
          position_id: string
          updated_at?: string
        }
        Update: {
          allowance_type_id?: string
          amount?: number
          created_at?: string
          id?: string
          position_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "position_allowances_allowance_type_id_fkey"
            columns: ["allowance_type_id"]
            isOneToOne: false
            referencedRelation: "allowance_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "position_allowances_position_id_fkey"
            columns: ["position_id"]
            isOneToOne: false
            referencedRelation: "positions"
            referencedColumns: ["id"]
          },
        ]
      }
      positions: {
        Row: {
          code: string
          created_at: string
          id: string
          is_active: boolean
          la_cong_nhat: boolean
          name: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          la_cong_nhat?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          la_cong_nhat?: boolean
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      sua_chua_cong: {
        Row: {
          employee_id: string | null
          id: string
          loai: Database["public"]["Enums"]["loai_sua_cong"]
          ly_do: string
          nguoi_sua: string
          phien_id: string | null
          sau: Json | null
          sua_luc: string
          truoc: Json | null
          work_date: string
        }
        Insert: {
          employee_id?: string | null
          id?: string
          loai: Database["public"]["Enums"]["loai_sua_cong"]
          ly_do: string
          nguoi_sua: string
          phien_id?: string | null
          sau?: Json | null
          sua_luc?: string
          truoc?: Json | null
          work_date: string
        }
        Update: {
          employee_id?: string | null
          id?: string
          loai?: Database["public"]["Enums"]["loai_sua_cong"]
          ly_do?: string
          nguoi_sua?: string
          phien_id?: string | null
          sau?: Json | null
          sua_luc?: string
          truoc?: Json | null
          work_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "sua_chua_cong_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sua_chua_cong_nguoi_sua_fkey"
            columns: ["nguoi_sua"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sua_chua_cong_phien_id_fkey"
            columns: ["phien_id"]
            isOneToOne: false
            referencedRelation: "phien_cham_cong_to"
            referencedColumns: ["id"]
          },
        ]
      }
      sua_tay_bang_thanh_toan: {
        Row: {
          bang_cu_id: string
          bang_goc_id: string
          bang_moi_id: string
          den_ngay: string
          employee_id: string
          id: string
          ly_do: string
          nguoi_sua: string
          nguoi_sua_ten: string
          sau: Json
          sua_luc: string
          ten_nhan_cong: string
          to_doi_id: string
          truoc: Json
          tu_ngay: string
        }
        Insert: {
          bang_cu_id: string
          bang_goc_id: string
          bang_moi_id: string
          den_ngay: string
          employee_id: string
          id?: string
          ly_do: string
          nguoi_sua: string
          nguoi_sua_ten: string
          sau: Json
          sua_luc?: string
          ten_nhan_cong: string
          to_doi_id: string
          truoc: Json
          tu_ngay: string
        }
        Update: {
          bang_cu_id?: string
          bang_goc_id?: string
          bang_moi_id?: string
          den_ngay?: string
          employee_id?: string
          id?: string
          ly_do?: string
          nguoi_sua?: string
          nguoi_sua_ten?: string
          sau?: Json
          sua_luc?: string
          ten_nhan_cong?: string
          to_doi_id?: string
          truoc?: Json
          tu_ngay?: string
        }
        Relationships: [
          {
            foreignKeyName: "sua_tay_bang_thanh_toan_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sua_tay_bang_thanh_toan_nguoi_sua_fkey"
            columns: ["nguoi_sua"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sua_tay_bang_thanh_toan_to_doi_id_fkey"
            columns: ["to_doi_id"]
            isOneToOne: false
            referencedRelation: "to_doi"
            referencedColumns: ["id"]
          },
        ]
      }
      to_doi: {
        Row: {
          code: string
          company_id: string
          created_at: string
          department_id: string | null
          ghi_chu: string | null
          id: string
          is_active: boolean
          name: string
          to_truong_id: string | null
          updated_at: string
        }
        Insert: {
          code: string
          company_id: string
          created_at?: string
          department_id?: string | null
          ghi_chu?: string | null
          id?: string
          is_active?: boolean
          name: string
          to_truong_id?: string | null
          updated_at?: string
        }
        Update: {
          code?: string
          company_id?: string
          created_at?: string
          department_id?: string | null
          ghi_chu?: string | null
          id?: string
          is_active?: boolean
          name?: string
          to_truong_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "to_doi_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "to_doi_department_id_fkey"
            columns: ["department_id"]
            isOneToOne: false
            referencedRelation: "departments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "to_doi_to_truong_id_fkey"
            columns: ["to_truong_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      to_doi_nguoi_cham: {
        Row: {
          app_user_id: string
          created_at: string
          ghi_chu: string | null
          id: string
          to_doi_id: string
          updated_at: string
        }
        Insert: {
          app_user_id: string
          created_at?: string
          ghi_chu?: string | null
          id?: string
          to_doi_id: string
          updated_at?: string
        }
        Update: {
          app_user_id?: string
          created_at?: string
          ghi_chu?: string | null
          id?: string
          to_doi_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "to_doi_nguoi_cham_app_user_id_fkey"
            columns: ["app_user_id"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "to_doi_nguoi_cham_to_doi_id_fkey"
            columns: ["to_doi_id"]
            isOneToOne: false
            referencedRelation: "to_doi"
            referencedColumns: ["id"]
          },
        ]
      }
      to_doi_thanh_vien: {
        Row: {
          created_at: string
          den_ngay: string | null
          don_gia_cong: number | null
          don_gia_gio: number | null
          don_gia_ot: number | null
          employee_id: string
          ghi_chu: string | null
          id: string
          kieu_tinh: string
          to_doi_id: string
          tu_ngay: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          den_ngay?: string | null
          don_gia_cong?: number | null
          don_gia_gio?: number | null
          don_gia_ot?: number | null
          employee_id: string
          ghi_chu?: string | null
          id?: string
          kieu_tinh?: string
          to_doi_id: string
          tu_ngay: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          den_ngay?: string | null
          don_gia_cong?: number | null
          don_gia_gio?: number | null
          don_gia_ot?: number | null
          employee_id?: string
          ghi_chu?: string | null
          id?: string
          kieu_tinh?: string
          to_doi_id?: string
          tu_ngay?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "to_doi_thanh_vien_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "to_doi_thanh_vien_to_doi_id_fkey"
            columns: ["to_doi_id"]
            isOneToOne: false
            referencedRelation: "to_doi"
            referencedColumns: ["id"]
          },
        ]
      }
      truy_linh_luong: {
        Row: {
          can_cu: Json
          employee_id: string
          id: string
          ly_do: string
          ngay_goc: string
          nguoi_tao: string
          period_id: string
          so_tien: number
          tao_luc: string
        }
        Insert: {
          can_cu: Json
          employee_id: string
          id?: string
          ly_do: string
          ngay_goc: string
          nguoi_tao: string
          period_id: string
          so_tien: number
          tao_luc?: string
        }
        Update: {
          can_cu?: Json
          employee_id?: string
          id?: string
          ly_do?: string
          ngay_goc?: string
          nguoi_tao?: string
          period_id?: string
          so_tien?: number
          tao_luc?: string
        }
        Relationships: [
          {
            foreignKeyName: "truy_linh_luong_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "truy_linh_luong_nguoi_tao_fkey"
            columns: ["nguoi_tao"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "truy_linh_luong_period_id_fkey"
            columns: ["period_id"]
            isOneToOne: false
            referencedRelation: "payroll_periods"
            referencedColumns: ["id"]
          },
        ]
      }
      work_shifts: {
        Row: {
          break_end: string | null
          break_start: string | null
          code: string
          created_at: string
          end_time: string
          id: string
          is_active: boolean
          name: string
          start_time: string
          updated_at: string
        }
        Insert: {
          break_end?: string | null
          break_start?: string | null
          code: string
          created_at?: string
          end_time: string
          id?: string
          is_active?: boolean
          name: string
          start_time: string
          updated_at?: string
        }
        Update: {
          break_end?: string | null
          break_start?: string | null
          code?: string
          created_at?: string
          end_time?: string
          id?: string
          is_active?: boolean
          name?: string
          start_time?: string
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      chung_tu_con_thieu: {
        Row: {
          chot_luc: string | null
          doi_tuong_id: string | null
          loai: Database["public"]["Enums"]["loai_chung_tu"] | null
          ten: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      bao_cao_luong_theo_ky: {
        Args: { p_company_id: string; p_den: number; p_tu: number }
        Returns: {
          bh_cong_ty: number
          bh_nguoi_lao_dong: number
          nam: number
          ngay_cong_chuan: number
          so_phieu: number
          thang: number
          tong_chi_phi: number
          tong_gross: number
          tong_net: number
          tong_ngay_cong: number
          tong_thue: number
          trang_thai: Database["public"]["Enums"]["period_status"]
        }[]
      }
      bao_cao_luong_theo_nhan_vien: {
        Args: { p_company_id: string; p_den: number; p_tu: number }
        Returns: {
          bh_cong_ty: number
          bh_nguoi_lao_dong: number
          employee_code: string
          full_name: string
          so_ky: number
          tong_gross: number
          tong_net: number
          tong_ngay_cong: number
          tong_thue: number
        }[]
      }
      bon_khoang_chong_nhau: {
        Args: {
          c_den: string
          c_tu: string
          n_den: string
          n_tu: string
          s_den: string
          s_tu: string
          t_den: string
          t_tu: string
        }
        Returns: boolean
      }
      can_manage_attendance: { Args: never; Returns: boolean }
      can_manage_payroll: { Args: never; Returns: boolean }
      can_read_all_employees: { Args: never; Returns: boolean }
      can_read_attendance_of: {
        Args: { p_employee_id: string }
        Returns: boolean
      }
      can_read_payroll: { Args: never; Returns: boolean }
      cham_bu_cong: {
        Args: {
          p_employee_id: string
          p_gio_ra: string
          p_gio_vao: string
          p_ly_do: string
          p_work_date: string
        }
        Returns: number
      }
      chot_ky_luong: { Args: { p_period_id: string }; Returns: undefined }
      chuc_danh_chinh_tai_ngay: {
        Args: { p_employee_id: string; p_ngay: string }
        Returns: string
      }
      chuc_danh_cua_nhan_vien: {
        Args: { p_employee_id: string; p_ngay: string }
        Returns: string[]
      }
      co_quyen: { Args: { p_quyen: string }; Returns: boolean }
      co_quyen_cua: {
        Args: { p_quyen: string; p_user_id: string }
        Returns: boolean
      }
      co_the_doc_bang_thanh_toan: {
        Args: { p_bang_id: string }
        Returns: boolean
      }
      co_the_doc_chung_tu: {
        Args: {
          p_doi_tuong_id: string
          p_loai: Database["public"]["Enums"]["loai_chung_tu"]
        }
        Returns: boolean
      }
      co_the_doc_chung_tu_theo_duong_dan: {
        Args: { p_duong_dan: string }
        Returns: boolean
      }
      cong_ty_cua_toi: { Args: never; Returns: string }
      current_app_role: {
        Args: never
        Returns: Database["public"]["Enums"]["user_role"]
      }
      current_company_id: { Args: never; Returns: string }
      current_department_id: { Args: never; Returns: string }
      current_employee_id: { Args: never; Returns: string }
      danh_dau_da_tra: { Args: { p_period_id: string }; Returns: undefined }
      doi_chuc_danh_chinh: {
        Args: {
          p_employee_id: string
          p_ly_do?: string
          p_position_id: string
          p_tu_ngay: string
        }
        Returns: undefined
      }
      ds_tai_khoan: {
        Args: never
        Returns: {
          dang_nhap_cuoi: string
          email: string
          employee_id: string
          full_name: string
          id: string
          is_active: boolean
          ma_nhan_vien: string
          quan_ly_to_doi: boolean
          role: Database["public"]["Enums"]["user_role"]
          tao_luc: string
          ten_nhan_vien: string
        }[]
      }
      duoc_duyet_cong_to: { Args: never; Returns: boolean }
      duoc_ghi_anh_phien: {
        Args: { p_phien_id: string; p_user_id: string }
        Returns: boolean
      }
      duoc_sua_chua_cong: { Args: never; Returns: boolean }
      ghi_chung_tu: {
        Args: {
          p_doi_tuong_id: string
          p_duong_dan: string
          p_kich_thuoc: number
          p_loai: Database["public"]["Enums"]["loai_chung_tu"]
          p_nguoi_tao: string
          p_sha256: string
          p_so_dong: number
          p_tieu_de: string
          p_tong_tien: number
        }
        Returns: {
          doi_tuong_id: string
          duong_dan: string
          id: string
          kich_thuoc: number
          loai: Database["public"]["Enums"]["loai_chung_tu"]
          nguoi_tao: string
          sha256: string
          so_dong: number
          so_hieu: string
          tao_luc: string
          tieu_de: string
          tong_tien: number
        }
        SetofOptions: {
          from: "*"
          to: "chung_tu"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      gio_ca_cong_nhat: {
        Args: {
          p_ca_chieu: boolean
          p_ca_sang: boolean
          p_ca_toi: boolean
          p_company_id: string
        }
        Returns: Record<string, unknown>
      }
      gio_cong_nhat_tu_khoang: {
        Args: {
          p_chieu_den: string
          p_chieu_tu: string
          p_company_id: string
          p_ngoai_den: string
          p_ngoai_tu: string
          p_sang_den: string
          p_sang_tu: string
          p_toi_den: string
          p_toi_tu: string
        }
        Returns: Record<string, unknown>
      }
      he_so_lam_them_hieu_luc: {
        Args: { p_ngay: string }
        Returns: {
          ngay_le_pct: number
          ngay_nghi_tuan_pct: number
          ngay_thuong_pct: number
        }[]
      }
      is_hr_or_admin: { Args: never; Returns: boolean }
      khoi_phuc_cham_cong: { Args: { p_log_id: string }; Returns: string }
      khoi_phuc_nhan_su: { Args: { p_employee_id: string }; Returns: undefined }
      ky_luong_cua_ngay: {
        Args: { p_employee_id: string; p_ngay: string }
        Returns: {
          closed_at: string | null
          closed_by: string | null
          company_id: string
          created_at: string
          id: string
          month: number
          standard_days: number
          status: Database["public"]["Enums"]["period_status"]
          updated_at: string
          year: number
        }
        SetofOptions: {
          from: "*"
          to: "payroll_periods"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      la_nguoi_cham_cong_phien: {
        Args: { p_phien_id: string }
        Returns: boolean
      }
      la_nguoi_cham_cong_to: { Args: { p_to_doi_id: string }; Returns: boolean }
      la_nguoi_cham_cong_to_txt: { Args: { p_id: string }; Returns: boolean }
      la_nguoi_cham_cua_nhan_su: {
        Args: { p_employee_id: string }
        Returns: boolean
      }
      la_nhan_cong_to_doi: { Args: { p_employee_id: string }; Returns: boolean }
      la_nhan_vien_chinh_thuc: { Args: { p_user_id: string }; Returns: boolean }
      la_quan_ly_to_doi: { Args: never; Returns: boolean }
      luong_bhxh_tai_ngay: {
        Args: { p_contract_id: string; p_ngay: string }
        Returns: number
      }
      luong_chuc_danh_binh_quan: {
        Args: { p_contract_id: string; p_den: string; p_tu: string }
        Returns: number
      }
      luong_chuc_danh_tai_ngay: {
        Args: { p_contract_id: string; p_ngay: string }
        Returns: number
      }
      mo_lai_phien_to: {
        Args: { p_ly_do: string; p_phien_id: string }
        Returns: undefined
      }
      muc_luong_trong_ky: {
        Args: { p_contract_id: string; p_den: string; p_tu: string }
        Returns: Json
      }
      phien_con_sua_duoc: { Args: { p_phien_id: string }; Returns: boolean }
      phu_cap_cua_nhan_vien: {
        Args: { p_employee_id: string; p_hop_dong: Json; p_ngay: string }
        Returns: Json
      }
      phu_cap_hop_dong_hop_le: { Args: { p: Json }; Returns: boolean }
      phut_giao_gio: {
        Args: {
          a_bat_dau: string
          a_ket_thuc: string
          b_bat_dau: string
          b_ket_thuc: string
        }
        Returns: number
      }
      phut_giao_nhau: {
        Args: {
          a_bat_dau: string
          a_ket_thuc: string
          b_bat_dau: string
          b_ket_thuc: string
        }
        Returns: number
      }
      phut_trong_ngay: {
        Args: { p_gio: string; p_la_dau_cuoi: boolean }
        Returns: number
      }
      quyen_tu_tab: {
        Args: { p_duyet_cong: boolean; p_tabs: string[] }
        Returns: string[]
      }
      sinh_bang_thanh_toan_to: {
        Args: { p_den_ngay: string; p_to_doi_id: string; p_tu_ngay: string }
        Returns: string
      }
      sua_nhan_cong_to: {
        Args: {
          p_cccd?: string
          p_don_gia_gio?: number
          p_don_gia_ot?: number
          p_ho_ten?: string
          p_thanh_vien_id: string
        }
        Returns: undefined
      }
      sua_tay_dong_thanh_toan_to: {
        Args: {
          p_don_gia: number
          p_don_gia_ot: number
          p_dong_id: string
          p_ly_do: string
          p_so_gio_ot: number
          p_so_luong: number
          p_thuong: number
        }
        Returns: string
      }
      tai_khoan_cua_toi: {
        Args: never
        Returns: {
          created_at: string
          duyet_cong: boolean
          employee_id: string | null
          full_name: string
          id: string
          is_active: boolean
          quan_ly_to_doi: boolean
          quyen: string[] | null
          role: Database["public"]["Enums"]["user_role"]
          tabs: string[] | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "app_users"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      tao_to_doi: {
        Args: {
          p_code: string
          p_department_id?: string
          p_ghi_chu?: string
          p_name: string
        }
        Returns: string
      }
      tao_truy_linh: {
        Args: {
          p_can_cu?: Json
          p_employee_id: string
          p_ly_do: string
          p_ngay_goc: string
          p_so_tien: number
        }
        Returns: {
          can_cu: Json
          employee_id: string
          id: string
          ly_do: string
          ngay_goc: string
          nguoi_tao: string
          period_id: string
          so_tien: number
          tao_luc: string
        }
        SetofOptions: {
          from: "*"
          to: "truy_linh_luong"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      thac_mac_phieu_luong: {
        Args: { p_ly_do: string; p_payslip_id: string }
        Returns: undefined
      }
      them_nhan_cong_to: {
        Args: {
          p_cccd?: string
          p_don_gia_gio?: number
          p_don_gia_ot?: number
          p_ho_ten: string
          p_to_doi_id: string
          p_tu_ngay?: string
        }
        Returns: string
      }
      thue_tncn: {
        Args: { p_ngay: string; p_thu_nhap_tinh_thue: number }
        Returns: number
      }
      thung_rac_cham_cong: {
        Args: never
        Returns: {
          check_type: Database["public"]["Enums"]["check_type"]
          deleted_at: string
          employee_code: string
          full_name: string
          id: string
          logged_at: string
          ly_do_xoa: string
          nguoi_xoa: string
        }[]
      }
      thung_rac_nhan_su: {
        Args: never
        Returns: {
          deleted_at: string
          employee_code: string
          full_name: string
          id: string
          ly_do_xoa: string
          nguoi_xoa: string
        }[]
      }
      tien_do_xac_nhan_ky: {
        Args: { p_period_id: string }
        Returns: {
          employee_code: string
          full_name: string
          ly_do: string
          trang_thai: Database["public"]["Enums"]["payslip_ack"]
          tu_dong: boolean
          xac_nhan_luc: string
        }[]
      }
      tinh_cong_mot_ngay: {
        Args: {
          p_ca_bat_dau: string
          p_ca_ket_thuc: string
          p_first_in: string
          p_last_out: string
          p_ngay: string
          p_nghi_bat_dau: string
          p_nghi_ket_thuc: string
          p_ot_in: string
          p_ot_out: string
        }
        Returns: {
          early_leave_minutes: number
          late_minutes: number
          ot_minutes: number
          status: Database["public"]["Enums"]["attendance_day_status"]
          worked_minutes: number
        }[]
      }
      tinh_luong_ky: { Args: { p_period_id: string }; Returns: number }
      tinh_luong_ky_cua_toi: { Args: { p_period_id: string }; Returns: number }
      tong_hop_cong_ngay: { Args: { p_ngay: string }; Returns: number }
      tong_hop_cong_ngay_cua_toi: { Args: { p_ngay: string }; Returns: number }
      tu_dong_xac_nhan_phieu_qua_han: {
        Args: { p_period_id?: string }
        Returns: number
      }
      xac_nhan_cham_cong_ngay: {
        Args: { p_ghi_chu?: string; p_ngay: string }
        Returns: number
      }
      xac_nhan_phieu_luong: {
        Args: { p_payslip_id: string }
        Returns: undefined
      }
      xoa_cham_cong: {
        Args: { p_log_id: string; p_ly_do: string }
        Returns: string
      }
      xoa_lan_cham_de_sua: {
        Args: { p_log_id: string; p_ly_do: string }
        Returns: undefined
      }
      xoa_nhan_su: {
        Args: { p_employee_id: string; p_ly_do: string }
        Returns: undefined
      }
    }
    Enums: {
      attendance_day_status:
        | "du_cong"
        | "thieu_gio"
        | "thieu_cham_ra"
        | "nghi"
        | "lam_ngay_nghi"
      check_type: "in" | "out" | "ot_in" | "ot_out"
      contract_type:
        | "thu_viec"
        | "xac_dinh_thoi_han"
        | "khong_xac_dinh"
        | "thoi_vu"
      employee_status:
        | "thu_viec"
        | "chinh_thuc"
        | "cong_tac_vien"
        | "nghi_viec"
        | "tam_hoan"
      loai_chung_tu: "bang_thanh_toan_to" | "ky_luong"
      loai_sua_cong: "cham_bu" | "xoa_lan_cham" | "mo_lai_phien" | "truy_linh"
      payslip_ack: "cho_xac_nhan" | "da_xac_nhan" | "thac_mac"
      period_status: "mo" | "da_chot" | "da_tra"
      user_role: "nhan_vien" | "truong_phong" | "hr" | "ke_toan" | "admin"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      attendance_day_status: [
        "du_cong",
        "thieu_gio",
        "thieu_cham_ra",
        "nghi",
        "lam_ngay_nghi",
      ],
      check_type: ["in", "out", "ot_in", "ot_out"],
      contract_type: [
        "thu_viec",
        "xac_dinh_thoi_han",
        "khong_xac_dinh",
        "thoi_vu",
      ],
      employee_status: [
        "thu_viec",
        "chinh_thuc",
        "cong_tac_vien",
        "nghi_viec",
        "tam_hoan",
      ],
      loai_chung_tu: ["bang_thanh_toan_to", "ky_luong"],
      loai_sua_cong: ["cham_bu", "xoa_lan_cham", "mo_lai_phien", "truy_linh"],
      payslip_ack: ["cho_xac_nhan", "da_xac_nhan", "thac_mac"],
      period_status: ["mo", "da_chot", "da_tra"],
      user_role: ["nhan_vien", "truong_phong", "hr", "ke_toan", "admin"],
    },
  },
} as const
