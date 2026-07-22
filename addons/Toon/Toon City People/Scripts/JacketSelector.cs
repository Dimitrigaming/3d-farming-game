using System.Collections.Generic;
using UnityEngine;

namespace JacketSelector
{

    public class JacketSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_JACKETS = 5
;
        [Range(0, MAXIMUM_NUMBER_JACKETS - 1)]
        public int Jacket;
        public GameObject[] Jackets = new GameObject[MAXIMUM_NUMBER_JACKETS];


        void OnValidate()
        {
		ValidateObject(Jacket, Jackets);

        }

        public void ValidateObject(int selectedIndex, GameObject[] objects)
        {
            if (selectedIndex > objects.Length)
                selectedIndex = objects.Length;

            for (int i = 0; i < objects.Length; i++)
            {
                if (objects[i] != null)
                    objects[i].SetActive(i == selectedIndex);
            }
        }
    }
}
