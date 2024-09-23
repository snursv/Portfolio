using System;
/*
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
*/
using System.Windows.Forms;
using Npgsql;


namespace WindowsFormsApp3
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
        }


        private void button1_Click(object sender, EventArgs e)
        {
            Cursor = Cursors.WaitCursor;
            LVData.Visible = false;
            LVData.Items.Clear();
            NpgsqlConnection conn = new NpgsqlConnection(textBox1.Text);

            try
            {
                conn.Open();
                NpgsqlCommand comm = new NpgsqlCommand(textBox2.Text, conn);
                NpgsqlDataReader reader;
                reader = comm.ExecuteReader();

                string str1 = "";
                LVData.Columns.Clear();
                for (int i = 0; i < reader.FieldCount; i++)
                {
                    LVData.Columns.Add(new ColumnHeader());    
                    LVData.Columns[i].Width = 100;
                    LVData.Columns[i].Text = reader.GetName(i);
                }

                while (reader.Read())
                {
                    str1 = "";
                    str1 = reader[0].ToString();
                    ListViewItem item1 = new ListViewItem(str1, 0);

                    for (int i = 1; i < reader.FieldCount; i++)
                        item1.SubItems.Add(reader[i].ToString());

                    LVData.Items.AddRange(new ListViewItem[] { item1 });
                }
            }
            catch (Exception ex)
            {
                Cursor = Cursors.Default;
                MessageBox.Show(ex.Message, "Ошибка", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                conn.Close();
                LVData.Visible = true;
                toolStripStatusLabel1.Text = LVData.Items.Count.ToString("N00") + "  записей";
                Cursor = Cursors.Default;
            }
        }

    }
}
